import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedFile;
  String? _fileName;
  double? _fileSize;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isUploading,
      loadingText: 'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100.h,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Upload Statement',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions
                    Container(
                      padding: EdgeInsets.all(AppSpacing.cardPadding),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        border: Border.all(color: AppColors.info.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20.w,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              'Upload your credit card statement to automatically extract bill details. We support PDF, JPG, and PNG files up to 10MB.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: AppSpacing.sectionSpacing),
                    
                    // Upload area
                    if (_selectedFile == null)
                      _UploadOptions(
                        onCameraTap: _pickFromCamera,
                        onGalleryTap: _pickFromGallery,
                        onFileTap: _pickFromFiles,
                      )
                    else
                      _FilePreview(
                        fileName: _fileName!,
                        fileSize: _fileSize!,
                        onRemove: _removeFile,
                      ),
                    
                    if (_errorMessage != null) ...[
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    SizedBox(height: AppSpacing.sectionSpacing),
                    
                    // Upload button
                    if (_selectedFile != null)
                      AppButton(
                        label: 'Upload Statement',
                        onPressed: _uploadFile,
                        isFullWidth: true,
                        icon: Icons.cloud_upload_outlined,
                      ),
                    
                    SizedBox(height: 32.h),
                    
                    // Recent uploads section
                    Text(
                      'Recent Uploads',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 16.h),
                    _RecentUploadsList(),
                    
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      
      if (photo != null) {
        _setSelectedFile(File(photo.path));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture image. Please try again.';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      
      if (image != null) {
        _setSelectedFile(File(image.path));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select image. Please try again.';
      });
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final sizeInMB = file.lengthSync() / (1024 * 1024);
        
        if (sizeInMB > 10) {
          setState(() {
            _errorMessage = 'File size must be less than 10MB';
          });
          return;
        }
        
        _setSelectedFile(file);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select file. Please try again.';
      });
    }
  }

  void _setSelectedFile(File file) {
    final sizeInMB = file.lengthSync() / (1024 * 1024);
    final extension = path.extension(file.path).toLowerCase();
    
    setState(() {
      _selectedFile = file;
      _fileName = path.basename(file.path);
      _fileSize = sizeInMB;
      _errorMessage = null;
    });
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _fileName = null;
      _fileSize = null;
      _errorMessage = null;
    });
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _errorMessage = null;
    });

    try {
      // Simulate upload progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() {
            _uploadProgress = i / 10;
          });
        }
      }

      // TODO: Replace with actual API upload
      // final result = await _apiService.uploadStatement(_selectedFile!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statement uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _removeFile();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Upload failed. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}

/// Upload options widget
class _UploadOptions extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onFileTap;

  const _UploadOptions({
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UploadOptionCard(
          icon: Icons.camera_alt_outlined,
          title: 'Take Photo',
          subtitle: 'Use camera to capture statement',
          color: AppColors.primary,
          onTap: onCameraTap,
        ),
        SizedBox(height: 12.h),
        _UploadOptionCard(
          icon: Icons.photo_library_outlined,
          title: 'Choose from Gallery',
          subtitle: 'Select a photo from your device',
          color: AppColors.success,
          onTap: onGalleryTap,
        ),
        SizedBox(height: 12.h),
        _UploadOptionCard(
          icon: Icons.folder_open_outlined,
          title: 'Browse Files',
          subtitle: 'Select PDF or image file',
          color: AppColors.warning,
          onTap: onFileTap,
        ),
      ],
    );
  }
}

class _UploadOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _UploadOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Icon(icon, color: color, size: 28.w),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// File preview widget
class _FilePreview extends StatelessWidget {
  final String fileName;
  final double fileSize;
  final VoidCallback onRemove;

  const _FilePreview({
    required this.fileName,
    required this.fileSize,
    required this.onRemove,
  });

  IconData _getFileIcon() {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  Color _getFileColor() {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.pdf')) return AppColors.error;
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return AppColors.success;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _getFileColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Icon(
                  _getFileIcon(),
                  color: _getFileColor(),
                  size: 32.w,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${fileSize.toStringAsFixed(2)} MB',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recent uploads list
class _RecentUploadsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual recent uploads from API
    final recentUploads = [
      _UploadHistory(
        fileName: 'statement_march_2024.pdf',
        uploadDate: DateTime.now().subtract(const Duration(days: 2)),
        status: UploadStatus.processed,
        cardName: 'CTBC Cash Back',
      ),
      _UploadHistory(
        fileName: 'IMG_20240315.jpg',
        uploadDate: DateTime.now().subtract(const Duration(days: 5)),
        status: UploadStatus.processed,
        cardName: 'Cathay Platinum',
      ),
      _UploadHistory(
        fileName: 'feb_statement.pdf',
        uploadDate: DateTime.now().subtract(const Duration(days: 30)),
        status: UploadStatus.processed,
        cardName: 'Taishin Rewards',
      ),
    ];

    return Column(
      children: recentUploads.map((upload) => _UploadHistoryTile(upload: upload)).toList(),
    );
  }
}

class _UploadHistoryTile extends StatelessWidget {
  final _UploadHistory upload;

  const _UploadHistoryTile({required this.upload});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            upload.fileName.endsWith('.pdf') 
                ? Icons.picture_as_pdf 
                : Icons.image,
            color: AppColors.lightTextSecondary,
            size: 24.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload.fileName,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  '${upload.cardName} • ${_formatDate(upload.uploadDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: upload.status == UploadStatus.processed
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Text(
              upload.status == UploadStatus.processed ? 'Processed' : 'Processing',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: upload.status == UploadStatus.processed
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} weeks ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}

enum UploadStatus { processing, processed }

class _UploadHistory {
  final String fileName;
  final DateTime uploadDate;
  final UploadStatus status;
  final String cardName;

  _UploadHistory({
    required this.fileName,
    required this.uploadDate,
    required this.status,
    required this.cardName,
  });
}
