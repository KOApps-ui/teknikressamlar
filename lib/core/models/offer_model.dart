import 'dart:convert';

class OfferAttachment {
  final String id;
  final String fileName;
  final String fileExtension;
  final int fileSize;
  final String? fileBase64;
  final String? localPath;

  OfferAttachment({
    required this.id,
    required this.fileName,
    required this.fileExtension,
    required this.fileSize,
    this.fileBase64,
    this.localPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'fileSize': fileSize,
      'fileBase64': fileBase64,
      'localPath': localPath,
    };
  }

  factory OfferAttachment.fromMap(Map<String, dynamic> map) {
    return OfferAttachment(
      id: map['id'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      fileExtension: map['fileExtension'] as String? ?? '',
      fileSize: map['fileSize'] as int? ?? 0,
      fileBase64: map['fileBase64'] as String?,
      localPath: map['localPath'] as String?,
    );
  }
}

class OfferModel {
  final String id;
  final String draftsmanId;
  final String draftsmanName;
  final String companyId;
  final String companyName;
  final String companyContact;
  final String projectTitle;
  final String description;
  final String branch;
  final String budget;
  final String projectDuration;
  final String deadline;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final bool isEncrypted;
  final String? encryptedPayload;
  final String? responseNote;
  final DateTime? respondedAt;

  // Attached project files / drawings / PDFs
  final List<OfferAttachment> attachments;

  // Company profile & contact details
  final String? companyEmail;
  final String? companyPhone;
  final String? companyCity;
  final String? companyBio;
  final String? companyWebsite;
  final String? companyTaxNumber;
  final bool? companyIsVerified;
  final String? companyVerificationBadge;
  final String? companyLogoBase64;
  final bool? companyIsVip;
  final String? companyTier;

  // Draftsman contact & profile details (shared upon acceptance or included)
  final String? draftsmanEmail;
  final String? draftsmanPhone;
  final String? draftsmanCity;
  final String? draftsmanTitle;
  final String? draftsmanBio;
  final String? draftsmanLinkedin;
  final String? draftsmanKariyerNet;

  OfferModel({
    required this.id,
    required this.draftsmanId,
    required this.draftsmanName,
    required this.companyId,
    required this.companyName,
    required this.companyContact,
    required this.projectTitle,
    required this.description,
    required this.branch,
    required this.budget,
    required this.projectDuration,
    required this.deadline,
    this.status = 'pending',
    required this.createdAt,
    this.isEncrypted = false,
    this.encryptedPayload,
    this.responseNote,
    this.respondedAt,
    this.attachments = const [],
    this.companyEmail,
    this.companyPhone,
    this.companyCity,
    this.companyBio,
    this.companyWebsite,
    this.companyTaxNumber,
    this.companyIsVerified,
    this.companyVerificationBadge,
    this.companyLogoBase64,
    this.companyIsVip,
    this.companyTier,
    this.draftsmanEmail,
    this.draftsmanPhone,
    this.draftsmanCity,
    this.draftsmanTitle,
    this.draftsmanBio,
    this.draftsmanLinkedin,
    this.draftsmanKariyerNet,
  });

  OfferModel copyWith({
    String? id,
    String? draftsmanId,
    String? draftsmanName,
    String? companyId,
    String? companyName,
    String? companyContact,
    String? projectTitle,
    String? description,
    String? branch,
    String? budget,
    String? projectDuration,
    String? deadline,
    String? status,
    DateTime? createdAt,
    bool? isEncrypted,
    String? encryptedPayload,
    String? responseNote,
    DateTime? respondedAt,
    List<OfferAttachment>? attachments,
    String? companyEmail,
    String? companyPhone,
    String? companyCity,
    String? companyBio,
    String? companyWebsite,
    String? companyTaxNumber,
    bool? companyIsVerified,
    String? companyVerificationBadge,
    String? companyLogoBase64,
    bool? companyIsVip,
    String? companyTier,
    String? draftsmanEmail,
    String? draftsmanPhone,
    String? draftsmanCity,
    String? draftsmanTitle,
    String? draftsmanBio,
    String? draftsmanLinkedin,
    String? draftsmanKariyerNet,
  }) {
    return OfferModel(
      id: id ?? this.id,
      draftsmanId: draftsmanId ?? this.draftsmanId,
      draftsmanName: draftsmanName ?? this.draftsmanName,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyContact: companyContact ?? this.companyContact,
      projectTitle: projectTitle ?? this.projectTitle,
      description: description ?? this.description,
      branch: branch ?? this.branch,
      budget: budget ?? this.budget,
      projectDuration: projectDuration ?? this.projectDuration,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      responseNote: responseNote ?? this.responseNote,
      respondedAt: respondedAt ?? this.respondedAt,
      attachments: attachments ?? this.attachments,
      companyEmail: companyEmail ?? this.companyEmail,
      companyPhone: companyPhone ?? this.companyPhone,
      companyCity: companyCity ?? this.companyCity,
      companyBio: companyBio ?? this.companyBio,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      companyTaxNumber: companyTaxNumber ?? this.companyTaxNumber,
      companyIsVerified: companyIsVerified ?? this.companyIsVerified,
      companyVerificationBadge: companyVerificationBadge ?? this.companyVerificationBadge,
      companyLogoBase64: companyLogoBase64 ?? this.companyLogoBase64,
      companyIsVip: companyIsVip ?? this.companyIsVip,
      companyTier: companyTier ?? this.companyTier,
      draftsmanEmail: draftsmanEmail ?? this.draftsmanEmail,
      draftsmanPhone: draftsmanPhone ?? this.draftsmanPhone,
      draftsmanCity: draftsmanCity ?? this.draftsmanCity,
      draftsmanTitle: draftsmanTitle ?? this.draftsmanTitle,
      draftsmanBio: draftsmanBio ?? this.draftsmanBio,
      draftsmanLinkedin: draftsmanLinkedin ?? this.draftsmanLinkedin,
      draftsmanKariyerNet: draftsmanKariyerNet ?? this.draftsmanKariyerNet,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'draftsmanId': draftsmanId,
      'draftsmanName': draftsmanName,
      'companyId': companyId,
      'companyName': companyName,
      'companyContact': companyContact,
      'projectTitle': projectTitle,
      'description': description,
      'branch': branch,
      'budget': budget,
      'projectDuration': projectDuration,
      'deadline': deadline,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'isEncrypted': isEncrypted,
      'encryptedPayload': encryptedPayload,
      'responseNote': responseNote,
      'respondedAt': respondedAt?.toIso8601String(),
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'companyEmail': companyEmail,
      'companyPhone': companyPhone,
      'companyCity': companyCity,
      'companyBio': companyBio,
      'companyWebsite': companyWebsite,
      'companyTaxNumber': companyTaxNumber,
      'companyIsVerified': companyIsVerified,
      'companyVerificationBadge': companyVerificationBadge,
      'companyLogoBase64': companyLogoBase64,
      'companyIsVip': companyIsVip,
      'companyTier': companyTier,
      'draftsmanEmail': draftsmanEmail,
      'draftsmanPhone': draftsmanPhone,
      'draftsmanCity': draftsmanCity,
      'draftsmanTitle': draftsmanTitle,
      'draftsmanBio': draftsmanBio,
      'draftsmanLinkedin': draftsmanLinkedin,
      'draftsmanKariyerNet': draftsmanKariyerNet,
    };
  }

  factory OfferModel.fromMap(Map<String, dynamic> map) {
    return OfferModel(
      id: map['id'] as String? ?? '',
      draftsmanId: map['draftsmanId'] as String? ?? '',
      draftsmanName: map['draftsmanName'] as String? ?? '',
      companyId: map['companyId'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      companyContact: map['companyContact'] as String? ?? '',
      projectTitle: map['projectTitle'] as String? ?? '',
      description: map['description'] as String? ?? '',
      branch: map['branch'] as String? ?? '',
      budget: map['budget'] as String? ?? '',
      projectDuration: map['projectDuration'] as String? ?? '',
      deadline: map['deadline'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isEncrypted: map['isEncrypted'] as bool? ?? false,
      encryptedPayload: map['encryptedPayload'] as String?,
      responseNote: map['responseNote'] as String?,
      respondedAt: map['respondedAt'] != null
          ? DateTime.tryParse(map['respondedAt'] as String)
          : null,
      attachments: (map['attachments'] as List?)
              ?.map((a) => OfferAttachment.fromMap(Map<String, dynamic>.from(a as Map)))
              .toList() ??
          const [],
      companyEmail: map['companyEmail'] as String?,
      companyPhone: map['companyPhone'] as String?,
      companyCity: map['companyCity'] as String?,
      companyBio: map['companyBio'] as String?,
      companyWebsite: map['companyWebsite'] as String?,
      companyTaxNumber: map['companyTaxNumber'] as String?,
      companyIsVerified: map['companyIsVerified'] as bool?,
      companyVerificationBadge: map['companyVerificationBadge'] as String?,
      companyLogoBase64: map['companyLogoBase64'] as String?,
      companyIsVip: map['companyIsVip'] as bool?,
      companyTier: map['companyTier'] as String?,
      draftsmanEmail: map['draftsmanEmail'] as String?,
      draftsmanPhone: map['draftsmanPhone'] as String?,
      draftsmanCity: map['draftsmanCity'] as String?,
      draftsmanTitle: map['draftsmanTitle'] as String?,
      draftsmanBio: map['draftsmanBio'] as String?,
      draftsmanLinkedin: map['draftsmanLinkedin'] as String?,
      draftsmanKariyerNet: map['draftsmanKariyerNet'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory OfferModel.fromJson(String source) =>
      OfferModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
