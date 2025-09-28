import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import '../models/user.dart';
import '../models/teacher.dart';
import '../models/reservation.dart';
import '../models/rating.dart';
import '../models/category.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/assignment.dart';

class ApiService {
  static const String baseUrl = kDebugMode 
      ? 'http://192.168.150.19:8080/api/v1'  // Local Development (PC IP)
      : 'http://34.77.40.180:8000/api/v1';    // Production VM
  late Dio _dio;
  String? _token;
  
  // Callback for unauthorized access
  Function()? onUnauthorized;
  final Map<String, dynamic> _cache = {};
  
  // Performance optimization
  Timer? _cacheCleanupTimer;

  ApiService() {
    if (kDebugMode) {
      print('🚀 [API_SERVICE] Initializing ApiService...');
      
      print('🌐 [API_SERVICE] Base URL: $baseUrl');
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (kDebugMode) {
          print('📤 [API_REQUEST] ${options.method} ${options.path}');
          print('📤 [API_REQUEST] Headers: ${options.headers}');
          print('📤 [API_REQUEST] Data: ${options.data}');
        }
        
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
          if (kDebugMode) {
            print('🔑 [API_REQUEST] Token added to headers');
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        if (kDebugMode) {
          print('📥 [API_RESPONSE] Status: ${response.statusCode}');
          print('📥 [API_RESPONSE] Data: ${response.data}');
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          print('❌ [API_ERROR] Status: ${error.response?.statusCode}');
          print('❌ [API_ERROR] Message: ${error.message}');
          print('❌ [API_ERROR] Response: ${error.response?.data}');
          print('❌ [API_ERROR] Request URL: ${error.requestOptions.path}');
          print('❌ [API_ERROR] Request Data: ${error.requestOptions.data}');
        }
        
        if (error.response?.statusCode == 401) {
          if (kDebugMode) {
            print('🔓 [API_ERROR] Unauthorized - clearing token');
          }
          await _clearToken();
          // Notify AuthBloc about unauthorized access
          _currentUser = null;
          if (onUnauthorized != null) {
            onUnauthorized!();
          }
        }
        handler.next(error);
      },
    ));

    _loadToken();
    _startCacheCleanup();
  }

  void _startCacheCleanup() {
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _cleanupCache();
    });
  }

  void _cleanupCache() {
    if (kDebugMode) {
      print('🧹 [CACHE_CLEANUP] Cleaning up expired cache entries...');
    }
    
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _cache.forEach((key, value) {
      if (value is Map<String, dynamic> && value.containsKey('expires_at')) {
        final expiresAt = DateTime.parse(value['expires_at']);
        if (now.isAfter(expiresAt)) {
          keysToRemove.add(key);
        }
      }
    });
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    
    if (kDebugMode && keysToRemove.isNotEmpty) {
      print('🧹 [CACHE_CLEANUP] Removed ${keysToRemove.length} expired cache entries');
    }
  }

  void dispose() {
    _cacheCleanupTimer?.cancel();
    _cache.clear();
  }

  Future<void> _loadToken() async {
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Loading token from SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (kDebugMode) {
      print('🔑 [API_SERVICE] Token loaded: ${_token != null ? "EXISTS" : "NULL"}');
    }
  }

  bool get isAuthenticated => _token != null;
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  int get currentUserId => _currentUser?.id ?? 0;

  Future<void> _saveToken(String token) async {
    if (kDebugMode) {
      print('💾 [API_SERVICE] Saving token to SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _token = token;
    if (kDebugMode) {
      print('💾 [API_SERVICE] Token saved successfully');
    }
  }

  Future<void> _clearToken() async {
    if (kDebugMode) {
      print('🗑️ [API_SERVICE] Clearing token from SharedPreferences...');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
    if (kDebugMode) {
      print('🗑️ [API_SERVICE] Token cleared successfully');
    }
  }

  // Auth endpoints
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String role,
  }) async {
    if (kDebugMode) {
      print('📝 [REGISTER] Starting registration process...');
      print('📝 [REGISTER] Name: $name');
      print('📝 [REGISTER] Email: $email');
      print('📝 [REGISTER] Role: $role');
      print('📝 [REGISTER] Password length: ${password.length}');
      print('📝 [REGISTER] Password confirmation length: ${passwordConfirmation.length}');
    }
    
    try {
      final requestData = {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      };
      
      if (kDebugMode) {
        print('📝 [REGISTER] Sending request to: /auth/register');
        print('📝 [REGISTER] Request data: $requestData');
      }
      
      final response = await _dio.post('/auth/register', data: requestData);

      if (kDebugMode) {
        print('✅ [REGISTER] Registration successful!');
        print('✅ [REGISTER] Response status: ${response.statusCode}');
        print('✅ [REGISTER] Response data: ${response.data}');
      }

      final token = response.data['token']['access_token'];
      await _saveToken(token);

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER] Registration failed with DioException');
        print('❌ [REGISTER] Error type: ${e.type}');
        print('❌ [REGISTER] Error message: ${e.message}');
        print('❌ [REGISTER] Response status: ${e.response?.statusCode}');
        print('❌ [REGISTER] Response data: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER] Registration failed with unexpected error: $e');
      }
      rethrow;
    }
  }

  // Social Authentication Methods
  Future<Map<String, dynamic>> googleLogin({
    required String accessToken,
    String? idToken,
  }) async {
    if (kDebugMode) {
      print('🔐 [GOOGLE_LOGIN] Starting Google login...');
    }
    
    try {
      final requestData = {
        'access_token': accessToken,
        if (idToken != null) 'id_token': idToken,
      };
      
      final response = await _dio.post('/auth/social/google', data: requestData);
      
      if (kDebugMode) {
        print('✅ [GOOGLE_LOGIN] Google login successful!');
        print('✅ [GOOGLE_LOGIN] Response: ${response.data}');
      }
      
      final data = response.data;
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GOOGLE_LOGIN] Google login failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> facebookLogin({
    required String accessToken,
  }) async {
    if (kDebugMode) {
      print('🔐 [FACEBOOK_LOGIN] Starting Facebook login...');
    }
    
    try {
      final requestData = {
        'access_token': accessToken,
      };
      
      final response = await _dio.post('/auth/social/facebook', data: requestData);
      
      if (kDebugMode) {
        print('✅ [FACEBOOK_LOGIN] Facebook login successful!');
      }
      
      final data = response.data;
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FACEBOOK_LOGIN] Facebook login failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> appleLogin({
    required String identityToken,
    String? authorizationCode,
  }) async {
    if (kDebugMode) {
      print('🔐 [APPLE_LOGIN] Starting Apple login...');
    }
    
    try {
      final requestData = {
        'identity_token': identityToken,
        if (authorizationCode != null) 'authorization_code': authorizationCode,
      };
      
      final response = await _dio.post('/auth/social/apple', data: requestData);
      
      if (kDebugMode) {
        print('✅ [APPLE_LOGIN] Apple login successful!');
      }
      
      final data = response.data;
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [APPLE_LOGIN] Apple login failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> linkSocialAccount({
    required String provider,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post('/auth/social/link', data: {
        'provider': provider,
        'access_token': accessToken,
      });
      
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LINK_SOCIAL] Failed to link social account: $e');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getLinkedAccounts() async {
    try {
      final response = await _dio.get('/auth/social/accounts');
      return List<Map<String, dynamic>>.from(response.data['accounts'] ?? []);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_LINKED_ACCOUNTS] Failed to get linked accounts: $e');
      }
      rethrow;
    }
  }

  Future<void> unlinkSocialAccount(String provider) async {
    try {
      await _dio.delete('/auth/social/unlink/$provider');
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UNLINK_SOCIAL] Failed to unlink social account: $e');
      }
      rethrow;
    }
  }

  // Profile management
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _dio.put('/profile', data: profileData);
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UPDATE_PROFILE] Failed to update profile: $e');
      }
      rethrow;
    }
  }

  Future<void> updatePassword(Map<String, dynamic> passwordData) async {
    try {
      await _dio.put('/profile/password', data: passwordData);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UPDATE_PASSWORD] Failed to update password: $e');
      }
      rethrow;
    }
  }

  // Mail status check
  Future<Map<String, dynamic>> getMailStatus() async {
    try {
      final response = await _dio.get('/auth/mail-status');
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [API_SERVICE] Mail status check failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (kDebugMode) {
      print('🔐 [LOGIN] Starting login process...');
      print('🔐 [LOGIN] Email: $email');
      print('🔐 [LOGIN] Password length: ${password.length}');
    }
    
    try {
      final requestData = {
        'email': email,
        'password': password,
      };
      
      if (kDebugMode) {
        print('🔐 [LOGIN] Sending request to: /auth/login');
        print('🔐 [LOGIN] Request data: $requestData');
      }
      
      final response = await _dio.post('/auth/login', data: requestData);

      if (kDebugMode) {
        print('✅ [LOGIN] Login successful!');
        print('✅ [LOGIN] Response status: ${response.statusCode}');
        print('✅ [LOGIN] Response data: ${response.data}');
      }

      final token = response.data['token']['access_token'];
      await _saveToken(token);

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [LOGIN] Login failed with DioException');
        print('❌ [LOGIN] Error type: ${e.type}');
        print('❌ [LOGIN] Error message: ${e.message}');
        print('❌ [LOGIN] Response status: ${e.response?.statusCode}');
        print('❌ [LOGIN] Response data: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOGIN] Login failed with unexpected error: $e');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      // Ignore logout errors
    } finally {
      await _clearToken();
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final response = await _dio.post('/auth/refresh');
      final token = response.data['token']['access_token'];
      await _saveToken(token);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // User endpoints
  Future<User> getProfile() async {
    try {
      final response = await _dio.get('/user');
      return User.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  // Teacher endpoints
  Future<Map<String, dynamic>> createTeacherProfile(Map<String, dynamic> profileData) async {
    if (kDebugMode) {
      print('📝 [CREATE_TEACHER_PROFILE] Starting teacher profile creation...');
      print('📝 [CREATE_TEACHER_PROFILE] Profile data: $profileData');
    }
    
    try {
      final response = await _dio.post('/teacher/profile', data: profileData);

      if (kDebugMode) {
        print('✅ [CREATE_TEACHER_PROFILE] Teacher profile created successfully!');
        print('✅ [CREATE_TEACHER_PROFILE] Response: ${response.data}');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_TEACHER_PROFILE] Teacher profile creation failed');
        print('❌ [CREATE_TEACHER_PROFILE] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_TEACHER_PROFILE] Unexpected error: $e');
      }
      throw Exception('Öğretmen profili oluşturulurken bir hata oluştu: $e');
    }
  }

  Future<List<User>> getTeacherStudents() async {
    try {
      final response = await _dio.get('/teacher/students');
      return (response.data['students'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getTeacherLessons() async {
    try {
      final response = await _dio.get('/teacher/lessons');
      return response.data['lessons'] as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getTeacherStatistics() async {
    try {
      final response = await _dio.get('/teacher/statistics');
      return response.data['statistics'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Teacher>> getTeachers({
    String? category,
    String? level,
    double? priceMin,
    double? priceMax,
    double? minRating,
    bool? onlineOnly,
    String? sortBy,
    String? search,
    int page = 1,
  }) async {
    try {
      // Cache key oluştur
      final cacheKey = 'teachers_${category}_${level}_${priceMin}_${priceMax}_${minRating}_${onlineOnly}_${sortBy}_${search}_$page';
      
      // Cache'den kontrol et
      if (_cache.containsKey(cacheKey)) {
        final cachedData = _cache[cacheKey];
        if (cachedData is Map<String, dynamic> && cachedData.containsKey('data')) {
          return cachedData['data'] as List<Teacher>;
        }
      }

      final queryParams = <String, dynamic>{
        'page': page,
      };

      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (level != null) queryParams['level'] = level;
      if (priceMin != null && priceMin > 0) queryParams['price_min'] = priceMin;
      if (priceMax != null && priceMax < 1000) queryParams['price_max'] = priceMax;
      if (minRating != null && minRating > 0) queryParams['min_rating'] = minRating;
      if (onlineOnly != null && onlineOnly) queryParams['online_only'] = onlineOnly;
      if (sortBy != null && sortBy.isNotEmpty) queryParams['sort_by'] = sortBy;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get('/teachers', queryParameters: queryParams);
      
      if (kDebugMode) {
        print('📡 Teachers API Response: ${response.statusCode}');
      }
      
      final teachers = (response.data['data'] as List)
          .map((json) => Teacher.fromJson(json))
          .toList();

      // Cache'e kaydet (5 dakika)
      _cache[cacheKey] = {
        'data': teachers,
        'expires_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      };
      
      return teachers;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Teacher>> getFeaturedTeachers() async {
    try {
      final response = await _dio.get('/teachers/featured');
      return (response.data['featured_teachers'] as List)
          .map((json) => Teacher.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  Future<Teacher> getTeacher(int teacherId) async {
    try {
      final response = await _dio.get('/teachers/$teacherId');
      return Teacher.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  Future<Teacher> updateTeacherProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/teacher/profile', data: data);
      return Teacher.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Category endpoints
  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      return (response.data as List)
          .map((json) => Category.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Category> getCategory(String slug) async {
    try {
      final response = await _dio.get('/categories/$slug');
      return Category.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Reservation endpoints
  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> reservationData) async {
    if (kDebugMode) {
      print('📅 [CREATE_RESERVATION] Starting reservation creation...');
      print('📅 [CREATE_RESERVATION] Reservation data: $reservationData');
    }
    
    try {
      final response = await _dio.post('/reservations', data: reservationData);

      if (kDebugMode) {
        print('✅ [CREATE_RESERVATION] Reservation created successfully!');
        print('✅ [CREATE_RESERVATION] Response: ${response.data}');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_RESERVATION] Reservation creation failed');
        print('❌ [CREATE_RESERVATION] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CREATE_RESERVATION] Unexpected error: $e');
      }
      throw Exception('Rezervasyon oluşturulurken bir hata oluştu: $e');
    }
  }

  // Chat endpoints
  Future<List<Chat>> getChats() async {
    if (kDebugMode) {
      print('💬 [GET_CHATS] Fetching chats...');
    }
    
    try {
      final response = await _dio.get('/chats');
      
      if (kDebugMode) {
        print('✅ [GET_CHATS] Chats fetched successfully!');
      }

      return (response.data['chats'] as List)
          .map((json) => Chat.fromJson(json))
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_CHATS] Failed to fetch chats');
        print('❌ [GET_CHATS] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_CHATS] Unexpected error: $e');
      }
      throw Exception('Chatler yüklenirken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> getOrCreateChat(int otherUserId) async {
    if (kDebugMode) {
      print('💬 [GET_OR_CREATE_CHAT] Getting or creating chat with user: $otherUserId');
    }
    
    try {
      final response = await _dio.post('/chats/get-or-create', data: {
        'other_user_id': otherUserId,
      });

      if (kDebugMode) {
        print('✅ [GET_OR_CREATE_CHAT] Chat retrieved successfully!');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_OR_CREATE_CHAT] Failed to get or create chat');
        print('❌ [GET_OR_CREATE_CHAT] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_OR_CREATE_CHAT] Unexpected error: $e');
      }
      throw Exception('Chat oluşturulurken bir hata oluştu: $e');
    }
  }

  Future<Message> sendMessage(int chatId, String content, {String type = 'text'}) async {
    if (kDebugMode) {
      print('💬 [SEND_MESSAGE] Sending message to chat: $chatId');
    }
    
    try {
      final response = await _dio.post('/chats/messages', data: {
        'chat_id': chatId,
        'content': content,
        'type': type,
      });

      if (kDebugMode) {
        print('✅ [SEND_MESSAGE] Message sent successfully!');
      }

      return Message.fromJson(response.data['message']);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [SEND_MESSAGE] Failed to send message');
        print('❌ [SEND_MESSAGE] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SEND_MESSAGE] Unexpected error: $e');
      }
      throw Exception('Mesaj gönderilirken bir hata oluştu: $e');
    }
  }

  Future<void> markMessagesAsRead(int chatId) async {
    if (kDebugMode) {
      print('💬 [MARK_AS_READ] Marking messages as read in chat: $chatId');
    }
    
    try {
      await _dio.put('/chats/mark-read', data: {
        'chat_id': chatId,
      });

      if (kDebugMode) {
        print('✅ [MARK_AS_READ] Messages marked as read successfully!');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [MARK_AS_READ] Failed to mark messages as read');
        print('❌ [MARK_AS_READ] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MARK_AS_READ] Unexpected error: $e');
      }
      throw Exception('Mesajlar okundu olarak işaretlenirken bir hata oluştu: $e');
    }
  }

  // Search endpoints
  Future<Map<String, dynamic>> searchTeachers({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? rating,
    String? location,
    String? sortBy,
    int page = 1,
    int perPage = 20,
  }) async {
    if (kDebugMode) {
      print('🔍 [SEARCH_TEACHERS] Searching teachers...');
    }
    
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (query != null && query.isNotEmpty) {
        queryParams['q'] = query;
      }
      if (category != null) {
        queryParams['category'] = category;
      }
      if (minPrice != null) {
        queryParams['min_price'] = minPrice;
      }
      if (maxPrice != null) {
        queryParams['max_price'] = maxPrice;
      }
      if (rating != null) {
        queryParams['rating'] = rating;
      }
      if (location != null) {
        queryParams['location'] = location;
      }
      if (sortBy != null) {
        queryParams['sort_by'] = sortBy;
      }

      final response = await _dio.get('/search/teachers', queryParameters: queryParams);

      if (kDebugMode) {
        print('✅ [SEARCH_TEACHERS] Search completed successfully!');
      }

      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [SEARCH_TEACHERS] Search failed');
        print('❌ [SEARCH_TEACHERS] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SEARCH_TEACHERS] Unexpected error: $e');
      }
      throw Exception('Öğretmen arama sırasında bir hata oluştu: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSearchSuggestions(String query, {int limit = 10}) async {
    if (kDebugMode) {
      print('🔍 [GET_SUGGESTIONS] Getting search suggestions for: $query');
    }
    
    try {
      final response = await _dio.get('/search/suggestions', queryParameters: {
        'q': query,
        'limit': limit,
      });

      if (kDebugMode) {
        print('✅ [GET_SUGGESTIONS] Suggestions retrieved successfully!');
      }

      return (response.data['suggestions'] as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SUGGESTIONS] Failed to get suggestions');
        print('❌ [GET_SUGGESTIONS] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SUGGESTIONS] Unexpected error: $e');
      }
      throw Exception('Arama önerileri alınırken bir hata oluştu: $e');
    }
  }

  Future<List<String>> getPopularSearches() async {
    if (kDebugMode) {
      print('🔍 [GET_POPULAR_SEARCHES] Getting popular searches...');
    }
    
    try {
      final response = await _dio.get('/search/popular');

      if (kDebugMode) {
        print('✅ [GET_POPULAR_SEARCHES] Popular searches retrieved successfully!');
      }

      return (response.data['popular_searches'] as List).cast<String>();
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_POPULAR_SEARCHES] Failed to get popular searches');
        print('❌ [GET_POPULAR_SEARCHES] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_POPULAR_SEARCHES] Unexpected error: $e');
      }
      throw Exception('Popüler aramalar alınırken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> getSearchFilters() async {
    if (kDebugMode) {
      print('🔍 [GET_SEARCH_FILTERS] Getting search filters...');
    }
    
    try {
      final response = await _dio.get('/search/filters');

      if (kDebugMode) {
        print('✅ [GET_SEARCH_FILTERS] Search filters retrieved successfully!');
      }

      return response.data['filters'];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SEARCH_FILTERS] Failed to get search filters');
        print('❌ [GET_SEARCH_FILTERS] Error: ${e.response?.data}');
      }
      throw _handleError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GET_SEARCH_FILTERS] Unexpected error: $e');
      }
      throw Exception('Arama filtreleri alınırken bir hata oluştu: $e');
    }
  }

  Future<List<Reservation>> getStudentReservations() async {
    try {
      final response = await _dio.get('/student/reservations');
      
      // Backend paginated response döndürüyor, data kısmını al
      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'] as List;
        return data.map((json) => Reservation.fromJson(json)).toList();
      } else {
        // Fallback: direkt array ise
        return (response.data as List)
            .map((json) => Reservation.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Reservation>> getTeacherReservations() async {
    try {
      final response = await _dio.get('/teacher/reservations');
      
      // Backend paginated response döndürüyor, data kısmını al
      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'] as List;
        return data.map((json) => Reservation.fromJson(json)).toList();
      } else {
        // Fallback: direkt array ise
        return (response.data as List)
            .map((json) => Reservation.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  Future<Reservation> updateReservation(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/reservations/$id', data: data);
      return Reservation.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteReservation(int id) async {
    try {
      await _dio.delete('/reservations/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Reservation> updateReservationStatus(int id, String status) async {
    try {
      final response = await _dio.put('/reservations/$id/status', data: {
        'status': status,
      });
      return Reservation.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Notification endpoints
  Future<Map<String, dynamic>> getNotifications({
    String? type,
    bool? isRead,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      
      if (type != null) queryParams['type'] = type;
      if (isRead != null) queryParams['is_read'] = isRead;

      final response = await _dio.get('/notifications', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      await _dio.put('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      await _dio.put('/notifications/read-all');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _dio.delete('/notifications/$notificationId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getNotificationStatistics() async {
    try {
      final response = await _dio.get('/notifications/statistics');
      return response.data['statistics'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Favorites endpoints
  Future<List<Teacher>> getFavorites() async {
    try {
      final response = await _dio.get('/favorites');
      return (response.data as List)
          .map((json) => Teacher.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> addToFavorites(int teacherId) async {
    try {
      await _dio.post('/favorites/$teacherId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> removeFromFavorites(int teacherId) async {
    try {
      await _dio.delete('/favorites/$teacherId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // File upload endpoints
  Future<Map<String, dynamic>> uploadProfilePhoto(String imagePath) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(imagePath),
      });

      final response = await _dio.post(
        '/upload/profile-photo',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      return response.data;
    } catch (e) {
      throw Exception('Profil fotoğrafı yüklenirken hata oluştu: $e');
    }
  }

  Future<void> deleteProfilePhoto() async {
    try {
      await _dio.delete('/upload/profile-photo');
    } catch (e) {
      throw Exception('Profil fotoğrafı silinirken hata oluştu: $e');
    }
  }

  // Rating endpoints
  Future<Rating> createRating({
    required int reservationId,
    required int rating,
    String? review,
  }) async {
    try {
      final response = await _dio.post('/ratings', data: {
        'reservation_id': reservationId,
        'rating': rating,
        'review': review,
      });
      return Rating.fromJson(response.data['rating']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Rating>> getStudentRatings() async {
    try {
      final response = await _dio.get('/student/ratings');
      return (response.data['data'] as List)
          .map((json) => Rating.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Rating>> getTeacherRatings(int teacherId) async {
    try {
      final response = await _dio.get('/teachers/$teacherId/ratings');
      return (response.data['data'] as List)
          .map((json) => Rating.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Rating> updateRating({
    required int ratingId,
    required int rating,
    String? review,
  }) async {
    try {
      final response = await _dio.put('/ratings/$ratingId', data: {
        'rating': rating,
        'review': review,
      });
      return Rating.fromJson(response.data['rating']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _dio.delete('/ratings/$ratingId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Email verification endpoints
  Future<void> verifyEmail(String email, String code) async {
    try {
      await _dio.post('/auth/verify-email-code', data: {
        'email': email,
        'verification_code': code,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> resendVerification(String email) async {
    try {
      await _dio.post('/auth/resend-verification', data: {
        'email': email,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Password reset endpoints
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await _dio.post('/auth/reset-password', data: {
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Admin endpoints
  Future<Map<String, dynamic>> getAdminDashboard() async {
    try {
      final response = await _dio.get('/admin/dashboard');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<User>> getAdminUsers({
    String? role,
    String? status,
  }) async {
    try {
      final response = await _dio.get('/admin/users', queryParameters: {
        if (role != null) 'role': role,
        if (status != null) 'status': status,
      });
      return (response.data['data'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateUserStatus(int userId, String status) async {
    try {
      await _dio.put('/admin/users/$userId/status', data: {
        'status': status,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getAdminReservations({String? status}) async {
    try {
      final response = await _dio.get('/admin/reservations', queryParameters: {
        if (status != null) 'status': status,
      });
      return response.data['data'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Teacher approval methods
  Future<List<User>> getPendingTeachers() async {
    try {
      final response = await _dio.get('/admin/teachers/pending');
      return (response.data['data'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> approveTeacher(int userId, {String? adminNotes}) async {
    try {
      await _dio.post('/admin/teachers/$userId/approve', data: {
        if (adminNotes != null) 'admin_notes': adminNotes,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> rejectTeacher(int userId, String rejectionReason, {String? adminNotes}) async {
    try {
      await _dio.post('/admin/teachers/$userId/reject', data: {
        'rejection_reason': rejectionReason,
        if (adminNotes != null) 'admin_notes': adminNotes,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<User>> getAllUsers({String? role, String? status, int page = 1}) async {
    try {
      final response = await _dio.get('/admin/users', queryParameters: {
        if (role != null) 'role': role,
        if (status != null) 'status': status,
        'page': page,
      });
      return (response.data['data'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> suspendUser(int userId, String reason) async {
    try {
      await _dio.post('/admin/users/$userId/suspend', data: {
        'reason': reason,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unsuspendUser(int userId) async {
    try {
      await _dio.post('/admin/users/$userId/unsuspend');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Push notification endpoints
  Future<void> registerPushToken(String token) async {
    try {
      await _dio.post('/notifications/register-token', data: {
        'token': token,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unregisterPushToken(String token) async {
    try {
      await _dio.post('/notifications/unregister-token', data: {
        'token': token,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Payment endpoints
  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> paymentData) async {
    try {
      final response = await _dio.post('/payments/create', data: paymentData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> confirmPayment(Map<String, dynamic> confirmationData) async {
    try {
      final response = await _dio.post('/payments/confirm', data: confirmationData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPaymentHistory({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/payments/history', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // File sharing endpoints
  Future<Map<String, dynamic>> getSharedFiles(int otherUserId, int? reservationId) async {
    try {
      final response = await _dio.get('/files/shared', queryParameters: {
        'other_user_id': otherUserId,
        'reservation_id': reservationId,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadSharedFile({
    required String filePath,
    required String fileName,
    required int receiverId,
    required String description,
    required String category,
    int? reservationId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'receiver_id': receiverId,
        'description': description,
        'category': category,
        if (reservationId != null) 'reservation_id': reservationId,
      });

      final response = await _dio.post('/files/upload-shared', data: formData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> downloadSharedFile(int fileId) async {
    try {
      final response = await _dio.get('/files/download/$fileId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteSharedFile(int fileId) async {
    try {
      final response = await _dio.delete('/files/$fileId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Reservations endpoints
  Future<List<Reservation>> getReservations({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      
      if (status != null) queryParams['status'] = status;
      if (fromDate != null) queryParams['from_date'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to_date'] = toDate.toIso8601String();

      final response = await _dio.get('/reservations', queryParameters: queryParams);
      
      final reservationsData = response.data['reservations'] as List;
      return reservationsData.map((json) => Reservation.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getReservationStatistics() async {
    try {
      final response = await _dio.get('/reservations/statistics');
      return response.data['statistics'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Assignment endpoints
  Future<List<Assignment>> getAssignments() async {
    try {
      final response = await _dio.get('/assignments');
      final assignmentsData = response.data['assignments'] as List;
      return assignmentsData.map((json) => Assignment.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createAssignment({
    required int studentId,
    required String title,
    required String description,
    required DateTime dueDate,
    required String difficulty,
    int? reservationId,
  }) async {
    try {
      final response = await _dio.post('/assignments', data: {
        'student_id': studentId,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'difficulty': difficulty,
        if (reservationId != null) 'reservation_id': reservationId,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitAssignment({
    required int assignmentId,
    String? submissionNotes,
    String? filePath,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'submission_notes': submissionNotes,
        if (filePath != null)
          'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post('/assignments/$assignmentId/submit', data: formData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  // Lesson endpoints
  Future<List<dynamic>> getUserLessons({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      
      if (status != null) queryParams['status'] = status;
      if (fromDate != null) queryParams['from_date'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to_date'] = toDate.toIso8601String();

      final response = await _dio.get('/lessons', queryParameters: queryParams);
      return response.data['lessons'] as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getLessonStatistics() async {
    try {
      final response = await _dio.get('/lessons/statistics');
      return response.data['statistics'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getUpcomingLessons() async {
    try {
      final response = await _dio.get('/lessons/upcoming');
      return response.data['upcoming_lessons'] as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentAssignments() async {
    try {
      final response = await _dio.get('/assignments/student');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getTeacherAssignments() async {
    try {
      final response = await _dio.get('/assignments/teacher');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> getUserById(int userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return User.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<User>> searchUsers(String query, {String? role}) async {
    try {
      final response = await _dio.get('/search/users', queryParameters: {
        'q': query,
        'role': role,
      });
      return (response.data['users'] as List)
          .map((json) => User.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }




  Future<Map<String, dynamic>> gradeAssignment(
    int assignmentId,
    String grade,
    String feedback,
  ) async {
    try {
      final response = await _dio.post('/assignments/$assignmentId/grade', data: {
        'grade': grade,
        'feedback': feedback,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Lesson management endpoints
  Future<Map<String, dynamic>> getLessonStatus(int reservationId) async {
    try {
      final response = await _dio.get('/lessons/status/$reservationId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> startLesson(int reservationId) async {
    try {
      final response = await _dio.post('/lessons/start', data: {
        'reservation_id': reservationId,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> endLesson(
    int reservationId,
    String notes,
    int rating,
    String feedback,
  ) async {
    try {
      final response = await _dio.post('/lessons/end', data: {
        'reservation_id': reservationId,
        'notes': notes,
        'rating': rating,
        'feedback': feedback,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      return response.data['count'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getAdminCategories() async {
    try {
      final response = await _dio.get('/admin/categories');
      return response.data['data'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createCategory({
    required String name,
    required String slug,
    String? description,
    int? parentId,
    String? icon,
    int? sortOrder,
  }) async {
    try {
      final response = await _dio.post('/admin/categories', data: {
        'name': name,
        'slug': slug,
        'description': description,
        'parent_id': parentId,
        'icon': icon,
        'sort_order': sortOrder,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getAuditLogs({String? action}) async {
    try {
      final response = await _dio.get('/admin/audit-logs', queryParameters: {
        if (action != null) 'action': action,
      });
      return response.data['data'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Content page endpoints
  Future<List<Map<String, dynamic>>> getContentPages() async {
    try {
      final response = await _dio.get('/content-pages');
      return (response.data['pages'] as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getContentPage(String slug) async {
    try {
      final response = await _dio.get('/content-pages/$slug');
      return response.data['page'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error handling
  String _handleError(DioException error) {
    if (kDebugMode) {
      print('🔍 [ERROR_HANDLER] Processing error: ${error.type}');
      print('🔍 [ERROR_HANDLER] Status: ${error.response?.statusCode}');
      print('🔍 [ERROR_HANDLER] Data: ${error.response?.data}');
    }
    
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        final errorData = data['error'];
        if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
          final message = errorData['message'];
          if (message is Map<String, dynamic>) {
            // Validation error - format the message
            final errors = <String>[];
            message.forEach((key, value) {
              if (value is List) {
                errors.addAll(value.map((e) => e.toString()));
              } else {
                errors.add(value.toString());
              }
            });
            return errors.join(', ');
          } else if (message is String) {
            return message;
          }
        }
        return 'Bir hata oluştu';
      }
      
      // Handle specific HTTP status codes
      switch (error.response!.statusCode) {
        case 400:
          return 'Geçersiz istek';
        case 401:
          return 'Yetkilendirme hatası';
        case 403:
          return 'Erişim reddedildi';
        case 404:
          return 'Kaynak bulunamadı';
        case 422:
          return 'Doğrulama hatası';
        case 429:
          return 'Çok fazla istek gönderildi';
        case 500:
          return 'Sunucu hatası';
        case 502:
          return 'Geçici sunucu hatası';
        case 503:
          return 'Servis kullanılamıyor';
        default:
          return 'Sunucu hatası: ${error.response!.statusCode}';
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Bağlantı zaman aşımı';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Yanıt zaman aşımı';
    } else if (error.type == DioExceptionType.sendTimeout) {
      return 'Gönderim zaman aşımı';
    } else if (error.type == DioExceptionType.connectionError) {
      return 'Bağlantı hatası';
    } else if (error.type == DioExceptionType.badResponse) {
      return 'Geçersiz yanıt';
    } else if (error.type == DioExceptionType.cancel) {
      return 'İstek iptal edildi';
    } else {
      return 'Ağ hatası: ${error.message}';
    }
  }

  // Teacher Availability Methods
  Future<List<Map<String, dynamic>>> getTeacherAvailabilities(int teacherId) async {
    try {
      final response = await _dio.get('/teachers/$teacherId/availabilities');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableSlots(int teacherId, String date) async {
    try {
      final response = await _dio.get('/teachers/$teacherId/available-slots', queryParameters: {
        'date': date,
      });
      return List<Map<String, dynamic>>.from(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addTeacherAvailability(String dayOfWeek, String startTime, String endTime) async {
    try {
      final response = await _dio.post('/teacher/availabilities', data: {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateTeacherAvailability(int id, String dayOfWeek, String startTime, String endTime) async {
    try {
      final response = await _dio.put('/teacher/availabilities/$id', data: {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteTeacherAvailability(int id) async {
    try {
      final response = await _dio.delete('/teacher/availabilities/$id');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  Future<List<Teacher>> getTrendingTeachers() async {
    try {
      final response = await _dio.get('/search/trending');
      return (response.data['data'] as List)
          .map((json) => Teacher.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }




  Future<Map<String, dynamic>> updateLessonNotes({
    required int lessonId,
    required String notes,
  }) async {
    try {
      final response = await _dio.put('/lessons/notes', data: {
        'lesson_id': lessonId,
        'notes': notes,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> rateLesson({
    required int lessonId,
    required int rating,
    String? feedback,
  }) async {
    try {
      final response = await _dio.post('/lessons/rate', data: {
        'lesson_id': lessonId,
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // User profile endpoints
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _dio.get('/user');
      return response.data['user'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _dio.put('/user', data: profileData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _dio.post('/user/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final response = await _dio.get('/user/statistics');
      return response.data['data'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getUserActivityHistory({
    String? action,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (action != null && action.isNotEmpty) queryParams['action'] = action;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final response = await _dio.get('/user/activity-history', queryParameters: queryParams);
      return response.data['data'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteUserAccount({
    required String password,
    required String confirmation,
  }) async {
    try {
      final response = await _dio.delete('/user/account', data: {
        'password': password,
        'confirmation': confirmation,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> exportUserData() async {
    try {
      final response = await _dio.get('/user/export-data');
      return response.data['data'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final response = await _dio.get('/user/notification-preferences');
      return response.data['data'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, dynamic> preferences) async {
    try {
      final response = await _dio.put('/user/notification-preferences', data: preferences);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> generatePresignedUrl(String filename, String contentType) async {
    try {
      final response = await _dio.post('/upload/presigned-url', data: {
        'filename': filename,
        'content_type': contentType,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> confirmUpload(String path, String filename, String fileType) async {
    try {
      final response = await _dio.post('/upload/confirm', data: {
        'path': path,
        'filename': filename,
        'file_type': fileType,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadDocument(XFile file, String type) async {
    try {
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
        'type': type,
      });

      final response = await _dio.post('/upload/document', data: formData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }



  // Generic HTTP methods
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // File upload method
  Future<Map<String, dynamic>> uploadFile(String endpoint, XFile file, Map<String, dynamic> data) async {
    try {
      final formData = FormData.fromMap({
        ...data,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
      });

      final response = await _dio.post(endpoint, data: formData);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Set current user
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // Admin Analytics
  Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      final response = await _dio.get('/admin/analytics');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}  
