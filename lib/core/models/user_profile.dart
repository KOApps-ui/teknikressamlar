import 'dart:convert';

class PortfolioFile {
  final String id;
  final String fileName;
  final String fileExtension;
  final String filePath;
  final int fileSize;
  final DateTime uploadDate;
  final String description;
  final String? fileBase64;

  PortfolioFile({
    required this.id,
    required this.fileName,
    required this.fileExtension,
    required this.filePath,
    required this.fileSize,
    required this.uploadDate,
    required this.description,
    this.fileBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'filePath': filePath,
      'fileSize': fileSize,
      'uploadDate': uploadDate.toIso8601String(),
      'description': description,
      'fileBase64': fileBase64,
    };
  }

  factory PortfolioFile.fromMap(Map<String, dynamic> map) {
    return PortfolioFile(
      id: map['id'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      fileExtension: map['fileExtension'] as String? ?? '',
      filePath: map['filePath'] as String? ?? '',
      fileSize: map['fileSize'] as int? ?? 0,
      uploadDate: map['uploadDate'] != null
          ? DateTime.tryParse(map['uploadDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      description: map['description'] as String? ?? '',
      fileBase64: map['fileBase64'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory PortfolioFile.fromJson(String source) =>
      PortfolioFile.fromMap(json.decode(source) as Map<String, dynamic>);
}

class CertificateItem {
  final String id;
  final String title;
  final String issuer;
  final String issueYear;
  final String? credentialId;
  final String? fileName;
  final String? filePath;
  final String? fileBase64;
  final int? fileSize;
  final DateTime? dateAdded;

  CertificateItem({
    required this.id,
    required this.title,
    required this.issuer,
    this.issueYear = '',
    this.credentialId,
    this.fileName,
    this.filePath,
    this.fileBase64,
    this.fileSize,
    this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'issuer': issuer,
      'issueYear': issueYear,
      'credentialId': credentialId,
      'fileName': fileName,
      'filePath': filePath,
      'fileBase64': fileBase64,
      'fileSize': fileSize,
      'dateAdded': dateAdded?.toIso8601String(),
    };
  }

  factory CertificateItem.fromMap(Map<String, dynamic> map) {
    return CertificateItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      issuer: map['issuer'] as String? ?? '',
      issueYear: map['issueYear'] as String? ?? '',
      credentialId: map['credentialId'] as String?,
      fileName: map['fileName'] as String?,
      filePath: map['filePath'] as String?,
      fileBase64: map['fileBase64'] as String?,
      fileSize: map['fileSize'] as int?,
      dateAdded: map['dateAdded'] != null
          ? DateTime.tryParse(map['dateAdded'] as String)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory CertificateItem.fromJson(String source) =>
      CertificateItem.fromMap(json.decode(source) as Map<String, dynamic>);
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'draftsman' or 'company'
  final String branch; // Çelik, Betonarme, Harita, Mekanik, Elektrik vb.
  final String title;
  final int experienceYears;
  final String bio;
  final List<String> softwareSkills;
  final String city;
  final List<PortfolioFile> portfolioFiles;
  final List<CertificateItem> certificates;
  final String publicKey;
  final String privateKey;
  final String authProvider; // 'local_did', 'google', 'linkedin'
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAvailable;
  final String? avatarPath;
  final String? avatarBase64;
  final bool isVerified;
  final String? verificationBadge;
  final String? diplomaBarcode;
  final String? taxNumber;
  final String? companyWebsite;
  final String? linkedinUrl;
  final String? kariyerNetUrl;
  final String? cvFileName;
  final String? cvFilePath;
  final String? cvBase64;
  final int? cvFileSize;
  final DateTime? cvUploadDate;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.branch,
    required this.title,
    required this.experienceYears,
    required this.bio,
    required this.softwareSkills,
    required this.city,
    required this.portfolioFiles,
    this.certificates = const [],
    required this.publicKey,
    required this.privateKey,
    required this.authProvider,
    required this.createdAt,
    required this.updatedAt,
    this.isAvailable = true,
    this.avatarPath,
    this.avatarBase64,
    this.isVerified = false,
    this.verificationBadge,
    this.diplomaBarcode,
    this.taxNumber,
    this.companyWebsite,
    this.linkedinUrl,
    this.kariyerNetUrl,
    this.cvFileName,
    this.cvFilePath,
    this.cvBase64,
    this.cvFileSize,
    this.cvUploadDate,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? branch,
    String? title,
    int? experienceYears,
    String? bio,
    List<String>? softwareSkills,
    String? city,
    List<PortfolioFile>? portfolioFiles,
    List<CertificateItem>? certificates,
    String? publicKey,
    String? privateKey,
    String? authProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAvailable,
    String? avatarPath,
    String? avatarBase64,
    bool? isVerified,
    String? verificationBadge,
    String? diplomaBarcode,
    String? taxNumber,
    String? companyWebsite,
    String? linkedinUrl,
    String? kariyerNetUrl,
    String? cvFileName,
    String? cvFilePath,
    String? cvBase64,
    int? cvFileSize,
    DateTime? cvUploadDate,
    bool clearCv = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      branch: branch ?? this.branch,
      title: title ?? this.title,
      experienceYears: experienceYears ?? this.experienceYears,
      bio: bio ?? this.bio,
      softwareSkills: softwareSkills ?? this.softwareSkills,
      city: city ?? this.city,
      portfolioFiles: portfolioFiles ?? this.portfolioFiles,
      certificates: certificates ?? this.certificates,
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAvailable: isAvailable ?? this.isAvailable,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      isVerified: isVerified ?? this.isVerified,
      verificationBadge: verificationBadge ?? this.verificationBadge,
      diplomaBarcode: diplomaBarcode ?? this.diplomaBarcode,
      taxNumber: taxNumber ?? this.taxNumber,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      kariyerNetUrl: kariyerNetUrl ?? this.kariyerNetUrl,
      cvFileName: clearCv ? null : (cvFileName ?? this.cvFileName),
      cvFilePath: clearCv ? null : (cvFilePath ?? this.cvFilePath),
      cvBase64: clearCv ? null : (cvBase64 ?? this.cvBase64),
      cvFileSize: clearCv ? null : (cvFileSize ?? this.cvFileSize),
      cvUploadDate: clearCv ? null : (cvUploadDate ?? this.cvUploadDate),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'branch': branch,
      'title': title,
      'experienceYears': experienceYears,
      'bio': bio,
      'softwareSkills': softwareSkills,
      'city': city,
      'portfolioFiles': portfolioFiles.map((x) => x.toMap()).toList(),
      'certificates': certificates.map((x) => x.toMap()).toList(),
      'publicKey': publicKey,
      'privateKey': privateKey,
      'authProvider': authProvider,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isAvailable': isAvailable,
      'avatarPath': avatarPath,
      'avatarBase64': avatarBase64,
      'isVerified': isVerified,
      'verificationBadge': verificationBadge,
      'diplomaBarcode': diplomaBarcode,
      'taxNumber': taxNumber,
      'companyWebsite': companyWebsite,
      'linkedinUrl': linkedinUrl,
      'kariyerNetUrl': kariyerNetUrl,
      'cvFileName': cvFileName,
      'cvFilePath': cvFilePath,
      'cvBase64': cvBase64,
      'cvFileSize': cvFileSize,
      'cvUploadDate': cvUploadDate?.toIso8601String(),
    };
  }

  // Public summary for P2P network broadcast (Zero-knowledge: does not share privateKey, phone, or raw files)
  Map<String, dynamic> toPublicSummaryMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'branch': branch,
      'title': title,
      'experienceYears': experienceYears,
      'bio': bio,
      'softwareSkills': softwareSkills,
      'city': city,
      'publicKey': publicKey,
      'portfolioCount': portfolioFiles.length,
      'avatarBase64': (avatarBase64 != null && avatarBase64!.length <= 80 * 1024) ? avatarBase64 : null,
      'isVerified': isVerified,
      'verificationBadge': verificationBadge,
      'diplomaBarcode': diplomaBarcode,
      'taxNumber': taxNumber,
      'linkedinUrl': linkedinUrl,
      'kariyerNetUrl': kariyerNetUrl,
      'hasCv': cvFileName != null && cvFileName!.isNotEmpty,
      'cvFileName': cvFileName,
      'cvFileSize': cvFileSize,
      'cvBase64': (cvBase64 != null && cvBase64!.length <= 300 * 1024) ? cvBase64 : null,
      'portfolioMeta': portfolioFiles
          .map((f) => {
                'id': f.id,
                'fileName': f.fileName,
                'extension': f.fileExtension,
                'size': f.fileSize,
                'description': f.description,
              })
          .toList(),
      'certificates': certificates
          .map((c) => {
                'id': c.id,
                'title': c.title,
                'issuer': c.issuer,
                'issueYear': c.issueYear,
                'credentialId': c.credentialId,
                'hasFile': c.fileName != null && c.fileName!.isNotEmpty,
                'fileName': c.fileName,
                'fileSize': c.fileSize,
              })
          .toList(),
      'isAvailable': isAvailable,
      'lastSeen': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: map['role'] as String? ?? 'draftsman',
      branch: map['branch'] as String? ?? 'Çelik Yapı & Konstrüksiyon',
      title: map['title'] as String? ?? '',
      experienceYears: map['experienceYears'] as int? ?? 0,
      bio: map['bio'] as String? ?? '',
      softwareSkills: List<String>.from(map['softwareSkills'] as List? ?? []),
      city: map['city'] as String? ?? '',
      portfolioFiles: (map['portfolioFiles'] as List? ?? [])
          .map((item) => PortfolioFile.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      certificates: (map['certificates'] as List? ?? [])
          .map((item) => CertificateItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      publicKey: map['publicKey'] as String? ?? '',
      privateKey: map['privateKey'] as String? ?? '',
      authProvider: map['authProvider'] as String? ?? 'local_did',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isAvailable: map['isAvailable'] as bool? ?? true,
      avatarPath: map['avatarPath'] as String?,
      avatarBase64: map['avatarBase64'] as String?,
      isVerified: map['isVerified'] as bool? ?? false,
      verificationBadge: map['verificationBadge'] as String?,
      diplomaBarcode: map['diplomaBarcode'] as String?,
      taxNumber: map['taxNumber'] as String?,
      companyWebsite: map['companyWebsite'] as String?,
      linkedinUrl: map['linkedinUrl'] as String?,
      kariyerNetUrl: map['kariyerNetUrl'] as String?,
      cvFileName: map['cvFileName'] as String?,
      cvFilePath: map['cvFilePath'] as String?,
      cvBase64: map['cvBase64'] as String?,
      cvFileSize: map['cvFileSize'] as int?,
      cvUploadDate: map['cvUploadDate'] != null
          ? DateTime.tryParse(map['cvUploadDate'] as String)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}
