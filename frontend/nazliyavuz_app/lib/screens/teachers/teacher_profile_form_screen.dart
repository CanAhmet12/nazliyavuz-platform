import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/teacher.dart';
import '../../models/category.dart';

class TeacherProfileFormScreen extends StatefulWidget {
  final Teacher? existingTeacher;

  const TeacherProfileFormScreen({
    super.key,
    this.existingTeacher,
  });

  @override
  State<TeacherProfileFormScreen> createState() => _TeacherProfileFormScreenState();
}

class _TeacherProfileFormScreenState extends State<TeacherProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Form controllers
  final _bioController = TextEditingController();
  final _priceController = TextEditingController();
  final _educationController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _languagesController = TextEditingController();
  
  // Form state
  List<Category> _categories = [];
  List<Category> _selectedCategories = [];
  List<String> _educationList = [];
  List<String> _certificationsList = [];
  List<String> _languagesList = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeForm();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _priceController.dispose();
    _educationController.dispose();
    _certificationsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Kategoriler yüklenirken hata oluştu: $e');
    }
  }

  void _initializeForm() {
    if (widget.existingTeacher != null) {
      final teacher = widget.existingTeacher!;
      _bioController.text = teacher.bio ?? '';
      _priceController.text = teacher.priceHour?.toString() ?? '';
      _selectedCategories = teacher.categories ?? [];
      _educationList = List.from(teacher.education ?? []);
      _certificationsList = List.from(teacher.certifications ?? []);
      _languagesList = List.from(teacher.languages ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTeacher != null ? 'Profil Düzenle' : 'Öğretmen Profili Oluştur'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.existingTeacher != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSubmitting ? null : _submitForm,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profil Bilgileri
                    _buildSectionCard(
                      'Profil Bilgileri',
                      [
                        _buildTextField(
                          controller: _bioController,
                          label: 'Hakkında',
                          hint: 'Kendinizi ve deneyimlerinizi kısaca anlatın',
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Hakkında bilgisi gerekli';
                            }
                            if (value.trim().length < 50) {
                              return 'En az 50 karakter olmalı';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _priceController,
                          label: 'Saatlik Ücret (TL)',
                          hint: 'Örn: 150',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Saatlik ücret gerekli';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Geçerli bir ücret girin';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kategoriler
                    _buildSectionCard(
                      'Uzmanlık Alanları',
                      [
                        Text(
                          'Hangi konularda ders verebiliyorsunuz?',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((category) {
                            final isSelected = _selectedCategories.any((c) => c.id == category.id);
                            return FilterChip(
                              label: Text(category.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.removeWhere((c) => c.id == category.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        if (_selectedCategories.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'En az bir kategori seçmelisiniz',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Eğitim
                    _buildSectionCard(
                      'Eğitim Geçmişi',
                      [
                        Text(
                          'Aldığınız eğitimleri ve derecelerinizi ekleyin',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildListInput(
                          controller: _educationController,
                          label: 'Eğitim',
                          hint: 'Örn: İstanbul Üniversitesi - Matematik Bölümü',
                          list: _educationList,
                          onAdd: (item) {
                            setState(() {
                              _educationList.add(item);
                            });
                          },
                          onRemove: (index) {
                            setState(() {
                              _educationList.removeAt(index);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ..._educationList.asMap().entries.map((entry) {
                          return _buildListItem(
                            entry.value,
                            () => _educationList.removeAt(entry.key),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sertifikalar
                    _buildSectionCard(
                      'Sertifikalar',
                      [
                        Text(
                          'Sahip olduğunuz sertifikaları ekleyin',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildListInput(
                          controller: _certificationsController,
                          label: 'Sertifika',
                          hint: 'Örn: Cambridge CELTA Sertifikası',
                          list: _certificationsList,
                          onAdd: (item) {
                            setState(() {
                              _certificationsList.add(item);
                            });
                          },
                          onRemove: (index) {
                            setState(() {
                              _certificationsList.removeAt(index);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ..._certificationsList.asMap().entries.map((entry) {
                          return _buildListItem(
                            entry.value,
                            () => _certificationsList.removeAt(entry.key),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Diller
                    _buildSectionCard(
                      'Konuştuğu Diller',
                      [
                        Text(
                          'Hangi dillerde ders verebiliyorsunuz?',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildListInput(
                          controller: _languagesController,
                          label: 'Dil',
                          hint: 'Örn: Türkçe, İngilizce',
                          list: _languagesList,
                          onAdd: (item) {
                            setState(() {
                              _languagesList.add(item);
                            });
                          },
                          onRemove: (index) {
                            setState(() {
                              _languagesList.removeAt(index);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ..._languagesList.asMap().entries.map((entry) {
                          return _buildListItem(
                            entry.value,
                            () => _languagesList.removeAt(entry.key),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                widget.existingTeacher != null ? 'Güncelle' : 'Profil Oluştur',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildListInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> list,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                onAdd(value.trim());
                controller.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              onAdd(controller.text.trim());
              controller.clear();
            }
          },
        ),
      ],
    );
  }

  Widget _buildListItem(String text, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      _showErrorSnackBar('En az bir kategori seçmelisiniz');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = {
        'bio': _bioController.text.trim(),
        'price_hour': double.parse(_priceController.text.trim()),
        'category_ids': _selectedCategories.map((c) => c.id).toList(),
        'education': _educationList,
        'certifications': _certificationsList,
        'languages': _languagesList,
      };

      if (widget.existingTeacher != null) {
        await _apiService.updateTeacherProfile(data);
      } else {
        await _apiService.createTeacherProfile(data);
      }

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar(
          widget.existingTeacher != null 
              ? 'Profil başarıyla güncellendi' 
              : 'Öğretmen profili başarıyla oluşturuldu'
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Hata: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
