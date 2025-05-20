import 'package:flutter/material.dart';
import '../widgets/custom_text.dart';
import 'package:hive/hive.dart';
import '../models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

/// 프로필 화면
/// 사용자 정보 확인 및 설정 화면 역할
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final userBox = Hive.box<User>('userBox');
  User? _user;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  
  // 폼 정보를 임시 저장할 변수들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _selectedGender = 'Male';
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
  
  // 사용자 데이터 가져오기
  void _loadUserData() {
    _user = userBox.get('profile');
    if (_user != null) {
      _nameController.text = _user!.name ?? '';
      _ageController.text = _user!.age?.toString() ?? '';
      _heightController.text = _user!.height?.toString() ?? '';
      _weightController.text = _user!.weight?.toString() ?? '';
      _selectedGender = _user!.gender ?? 'Male';
      
      // 사용자가 저장한 성별이 현재 드롭다운 옵션에 없는 경우 처리
      if (!_genderOptions.contains(_selectedGender)) {
        _selectedGender = 'Male'; // 매칭되는 값이 없으면 기본값으로 설정
      }
      
      if (_user!.profileImagePath != null) {
        setState(() {
          _profileImage = File(_user!.profileImagePath!);
        });
      }
      
      // UUID 없으면 새로 생성
      if (_user!.uuid == null) {
        final uuid = const Uuid().v4();
        _user!.uuid = uuid;
        userBox.put('profile', _user!);
      }
    } else {
      // 사용자 없으면 생성
      final uuid = const Uuid().v4();
      _user = User(uuid: uuid);
      userBox.put('profile', _user!);
    }
  }
  
  // 프로필 사진 선택
  Future<void> _selectProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
      
      // 사진을 저장 디렉토리로 복사
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${_user!.uuid}.jpg';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      
      // 사용자 정보 업데이트
      _user!.profileImagePath = savedImage.path;
      userBox.put('profile', _user!);
    }
  }
  
  // 사용자 정보 저장
  void _saveUserInfo() {
    if (_formKey.currentState!.validate()) {
      if (_user == null) {
        final uuid = const Uuid().v4();
        _user = User(
          name: _nameController.text,
          age: int.tryParse(_ageController.text),
          gender: _selectedGender,
          height: double.tryParse(_heightController.text),
          weight: double.tryParse(_weightController.text),
          profileImagePath: _profileImage?.path,
          uuid: uuid,
        );
      } else {
        _user!.name = _nameController.text;
        _user!.age = int.tryParse(_ageController.text);
        _user!.gender = _selectedGender;
        _user!.height = double.tryParse(_heightController.text);
        _user!.weight = double.tryParse(_weightController.text);
      }
      
      userBox.put('profile', _user!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 저장되었습니다')),
      );
    }
  }

  // 프로필 정보 타일 빌딩
  List<Widget> _buildProfileTiles() {
    if (_user == null) {
      return [
        const ListTile(
          title: CustomText(text: 'No profile data found.'),
        ),
      ];
    }
    
    return [
      // 프로필 사진 영역
      Center(
        child: GestureDetector(
          onTap: _selectProfileImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) as ImageProvider
                    : null,
                child: _profileImage == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
    
      // 프로필 폼
      Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Please enter your age' : null,
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: _genderOptions.map((gender) {
                return DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedGender = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Please enter your height' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Please enter your weight' : null,
            ),
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _saveUserInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
  backgroundColor: Colors.grey[800],
  elevation: 0,
  iconTheme: const IconThemeData(color: Colors.white),
  title: const Text(
    'Profile',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: _buildProfileTiles(),
        ),
      ),
    );
  }
}
