import '../../core/constants/app_constants.dart';

class IncidentModel {
  final String id;
  final String title;
  final String descriptionOriginal;
  final String descriptionTranslated;
  final String originalLanguage;
  final IncidentCategory category;
  final double latitude;
  final double longitude;
  final String address;
  final bool isLocationApproximate;
  final IncidentStatus status;
  final double priorityScore;
  final String priorityExplanation;
  final List<String> vulnerableGroups; // Children, Elderly, Pregnant, Disability, Hospital
  final bool hasVoiceNote;
  final String? voiceNoteUrl;
  final String source; // CITIZEN_WEB, ONE_TAP_SOS, DAMAGE_REPORT, SMS_GATEWAY, WHATSAPP, 112_DISPATCH
  final String reporterPhoneMasked;
  final DateTime reportedAt;
  final String? assignedTeam;
  final bool isPossibleDuplicate;
  final String? duplicateOfId;
  final double duplicateConfidence;
  final bool duplicateConfirmedByHuman;
  final Map<String, dynamic>? whatIfSimulation;

  // Detailed Disaster Damage & Assistance Fields (Part 6 & 7)
  final List<String> affectedProperties; // Home, Agricultural Land, Livestock, Business, Assets
  final double? estimatedLossInr;
  final int? householdMembersCount;
  final String? urgentMedicalNeeds;
  final List<String> reliefRequirements; // Food, Water, Shelter, Clothing, Medicine
  final List<String> evidencePhotos;
  final String? preferredFollowUp; // SMS, Phone, Field Visit
  final int missingPersonsCount;
  final String? missingPersonsDetails;
  final bool missingPersonEmergencyAssistanceNeeded;
  final List<String> lostDocuments; // Aadhaar, Ration Card, Land Records, Bank Passbook, Insurance
  final String? immediateSafetyConcerns;

  // Traceable Incident Verification Fields (Part 7 & 8)
  final String? reviewerId;
  final String? reviewerName;
  final String? reviewerRole;
  final String? reviewerNotes;
  final String? decisionReason;
  final List<String> verificationHistory;
  final String? departmentAssigned;
  final String? escalatedTo;

  // Government Relief Sanction & Delivery Fields (Part 8 & 11)
  final bool? governmentAssistanceApproved;
  final double? sanctionedAmountInr;
  final double? assistanceDeliveredInr;
  final String? reliefAssistanceCategory;
  final String? assistanceDeliveryStatus; // 'PENDING_SANCTION', 'SANCTIONED', 'DISBURSED', 'REJECTED'
  final String? assistanceRejectionReason;

  // Connected End-to-End Workflow Fields (Workstream D)
  final String? acceptedBy;
  final String? acceptedRole;
  final bool citizenReceiptConfirmed;
  final bool citizenReceiptDisputed;
  final String? citizenDisputeReason;
  final bool foundConfirmedByCitizen;
  final bool foundConfirmedByAuthority;
  final bool sosRescuedConfirmedByCitizen;
  final bool sosRescuedConfirmedByResponder;

  IncidentModel({
    required this.id,
    required this.title,
    required this.descriptionOriginal,
    required this.descriptionTranslated,
    this.originalLanguage = 'en',
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.isLocationApproximate = false,
    this.status = IncidentStatus.received,
    required this.priorityScore,
    required this.priorityExplanation,
    this.vulnerableGroups = const [],
    this.hasVoiceNote = false,
    this.voiceNoteUrl,
    this.source = 'CITIZEN_WEB',
    required this.reporterPhoneMasked,
    required this.reportedAt,
    this.assignedTeam,
    this.isPossibleDuplicate = false,
    this.duplicateOfId,
    this.duplicateConfidence = 0.0,
    this.duplicateConfirmedByHuman = false,
    this.whatIfSimulation,
    this.affectedProperties = const [],
    this.estimatedLossInr,
    this.householdMembersCount,
    this.urgentMedicalNeeds,
    this.reliefRequirements = const [],
    this.evidencePhotos = const [],
    this.preferredFollowUp,
    this.missingPersonsCount = 0,
    this.missingPersonsDetails,
    this.missingPersonEmergencyAssistanceNeeded = false,
    this.lostDocuments = const [],
    this.immediateSafetyConcerns,
    this.reviewerId,
    this.reviewerName,
    this.reviewerRole,
    this.reviewerNotes,
    this.decisionReason,
    this.verificationHistory = const [],
    this.departmentAssigned,
    this.escalatedTo,
    this.governmentAssistanceApproved,
    this.sanctionedAmountInr,
    this.assistanceDeliveredInr,
    this.reliefAssistanceCategory,
    this.assistanceDeliveryStatus,
    this.assistanceRejectionReason,
    this.acceptedBy,
    this.acceptedRole,
    this.citizenReceiptConfirmed = false,
    this.citizenReceiptDisputed = false,
    this.citizenDisputeReason,
    this.foundConfirmedByCitizen = false,
    this.foundConfirmedByAuthority = false,
    this.sosRescuedConfirmedByCitizen = false,
    this.sosRescuedConfirmedByResponder = false,
  });

  IncidentModel copyWith({
    String? id,
    String? title,
    String? descriptionOriginal,
    String? descriptionTranslated,
    String? originalLanguage,
    IncidentCategory? category,
    double? latitude,
    double? longitude,
    String? address,
    bool? isLocationApproximate,
    IncidentStatus? status,
    double? priorityScore,
    String? priorityExplanation,
    List<String>? vulnerableGroups,
    bool? hasVoiceNote,
    String? voiceNoteUrl,
    String? source,
    String? reporterPhoneMasked,
    DateTime? reportedAt,
    String? assignedTeam,
    bool? isPossibleDuplicate,
    String? duplicateOfId,
    double? duplicateConfidence,
    bool? duplicateConfirmedByHuman,
    Map<String, dynamic>? whatIfSimulation,
    List<String>? affectedProperties,
    double? estimatedLossInr,
    int? householdMembersCount,
    String? urgentMedicalNeeds,
    List<String>? reliefRequirements,
    List<String>? evidencePhotos,
    String? preferredFollowUp,
    int? missingPersonsCount,
    String? missingPersonsDetails,
    bool? missingPersonEmergencyAssistanceNeeded,
    List<String>? lostDocuments,
    String? immediateSafetyConcerns,
    String? reviewerId,
    String? reviewerName,
    String? reviewerRole,
    String? reviewerNotes,
    String? decisionReason,
    List<String>? verificationHistory,
    String? departmentAssigned,
    String? escalatedTo,
    bool? governmentAssistanceApproved,
    double? sanctionedAmountInr,
    double? assistanceDeliveredInr,
    String? reliefAssistanceCategory,
    String? assistanceDeliveryStatus,
    String? assistanceRejectionReason,
    String? acceptedBy,
    String? acceptedRole,
    bool? citizenReceiptConfirmed,
    bool? citizenReceiptDisputed,
    String? citizenDisputeReason,
    bool? foundConfirmedByCitizen,
    bool? foundConfirmedByAuthority,
    bool? sosRescuedConfirmedByCitizen,
    bool? sosRescuedConfirmedByResponder,
  }) {
    return IncidentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      descriptionOriginal: descriptionOriginal ?? this.descriptionOriginal,
      descriptionTranslated: descriptionTranslated ?? this.descriptionTranslated,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      isLocationApproximate: isLocationApproximate ?? this.isLocationApproximate,
      status: status ?? this.status,
      priorityScore: priorityScore ?? this.priorityScore,
      priorityExplanation: priorityExplanation ?? this.priorityExplanation,
      vulnerableGroups: vulnerableGroups ?? this.vulnerableGroups,
      hasVoiceNote: hasVoiceNote ?? this.hasVoiceNote,
      voiceNoteUrl: voiceNoteUrl ?? this.voiceNoteUrl,
      source: source ?? this.source,
      reporterPhoneMasked: reporterPhoneMasked ?? this.reporterPhoneMasked,
      reportedAt: reportedAt ?? this.reportedAt,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      isPossibleDuplicate: isPossibleDuplicate ?? this.isPossibleDuplicate,
      duplicateOfId: duplicateOfId ?? this.duplicateOfId,
      duplicateConfidence: duplicateConfidence ?? this.duplicateConfidence,
      duplicateConfirmedByHuman: duplicateConfirmedByHuman ?? this.duplicateConfirmedByHuman,
      whatIfSimulation: whatIfSimulation ?? this.whatIfSimulation,
      affectedProperties: affectedProperties ?? this.affectedProperties,
      estimatedLossInr: estimatedLossInr ?? this.estimatedLossInr,
      householdMembersCount: householdMembersCount ?? this.householdMembersCount,
      urgentMedicalNeeds: urgentMedicalNeeds ?? this.urgentMedicalNeeds,
      reliefRequirements: reliefRequirements ?? this.reliefRequirements,
      evidencePhotos: evidencePhotos ?? this.evidencePhotos,
      preferredFollowUp: preferredFollowUp ?? this.preferredFollowUp,
      missingPersonsCount: missingPersonsCount ?? this.missingPersonsCount,
      missingPersonsDetails: missingPersonsDetails ?? this.missingPersonsDetails,
      missingPersonEmergencyAssistanceNeeded: missingPersonEmergencyAssistanceNeeded ?? this.missingPersonEmergencyAssistanceNeeded,
      lostDocuments: lostDocuments ?? this.lostDocuments,
      immediateSafetyConcerns: immediateSafetyConcerns ?? this.immediateSafetyConcerns,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerRole: reviewerRole ?? this.reviewerRole,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      decisionReason: decisionReason ?? this.decisionReason,
      verificationHistory: verificationHistory ?? this.verificationHistory,
      departmentAssigned: departmentAssigned ?? this.departmentAssigned,
      escalatedTo: escalatedTo ?? this.escalatedTo,
      governmentAssistanceApproved: governmentAssistanceApproved ?? this.governmentAssistanceApproved,
      sanctionedAmountInr: sanctionedAmountInr ?? this.sanctionedAmountInr,
      assistanceDeliveredInr: assistanceDeliveredInr ?? this.assistanceDeliveredInr,
      reliefAssistanceCategory: reliefAssistanceCategory ?? this.reliefAssistanceCategory,
      assistanceDeliveryStatus: assistanceDeliveryStatus ?? this.assistanceDeliveryStatus,
      assistanceRejectionReason: assistanceRejectionReason ?? this.assistanceRejectionReason,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedRole: acceptedRole ?? this.acceptedRole,
      citizenReceiptConfirmed: citizenReceiptConfirmed ?? this.citizenReceiptConfirmed,
      citizenReceiptDisputed: citizenReceiptDisputed ?? this.citizenReceiptDisputed,
      citizenDisputeReason: citizenDisputeReason ?? this.citizenDisputeReason,
      foundConfirmedByCitizen: foundConfirmedByCitizen ?? this.foundConfirmedByCitizen,
      foundConfirmedByAuthority: foundConfirmedByAuthority ?? this.foundConfirmedByAuthority,
      sosRescuedConfirmedByCitizen: sosRescuedConfirmedByCitizen ?? this.sosRescuedConfirmedByCitizen,
      sosRescuedConfirmedByResponder: sosRescuedConfirmedByResponder ?? this.sosRescuedConfirmedByResponder,
    );
  }

  // Calculate explainable priority score
  static double calculatePriority({
    required IncidentCategory category,
    required int casualties,
    required int trappedCount,
    required bool hasVulnerable,
    required double waterLevelMeters,
    required bool isNightTime,
  }) {
    double score = category.baseWeight * 30.0;
    score += (casualties * 15.0).clamp(0, 30);
    score += (trappedCount * 5.0).clamp(0, 20);
    if (hasVulnerable) score += 15.0;
    if (waterLevelMeters > 1.5) score += 10.0;
    if (isNightTime) score += 5.0;
    return score.clamp(10.0, 100.0);
  }
}
