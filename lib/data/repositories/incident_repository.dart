import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/models/incident_model.dart';
import '../../shared/models/alert_model.dart';
import '../../shared/models/shelter_model.dart';
import '../../shared/models/volunteer_model.dart';
import '../../shared/models/rumor_model.dart';
import '../services/demo_data_service.dart';
import '../services/storage_service.dart';

// User and Role State
final activeRoleProvider = StateProvider<UserRole>((ref) {
  try {
    final savedRole = StorageService.getString(StorageService.keyActiveRole);
    if (savedRole != null && savedRole.isNotEmpty) {
      for (final r in UserRole.values) {
        if (r.name == savedRole || r.title == savedRole) {
          return r;
        }
      }
    }
  } catch (_) {}
  return UserRole.citizen;
});

// Incidents State Notifier
class IncidentsNotifier extends StateNotifier<List<IncidentModel>> {
  IncidentsNotifier() : super(DemoDataService.getInitialIncidents());

  void addIncident(IncidentModel incident) {
    state = [incident, ...state];
  }

  void updateStatus(String id, IncidentStatus newStatus, {String? team}) {
    state = state.map((item) {
      if (item.id == id) {
        final historyEntry = '${DateTime.now().toIso8601String().substring(0, 16)}: Status changed to ${newStatus.label}${team != null ? " (Team: $team)" : ""}';
        return item.copyWith(
          status: newStatus,
          assignedTeam: team ?? item.assignedTeam,
          verificationHistory: [historyEntry, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void recordVerificationDecision(
    String id, {
    required IncidentStatus newStatus,
    required String reviewerId,
    required String reviewerName,
    required String reviewerRole,
    required String notes,
    required String reason,
    String? departmentAssigned,
  }) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: [${reviewerRole.toUpperCase()}] $reviewerName designated as ${newStatus.label}. Reason: $reason. Notes: $notes';
        return item.copyWith(
          status: newStatus,
          reviewerId: reviewerId,
          reviewerName: reviewerName,
          reviewerRole: reviewerRole,
          reviewerNotes: notes,
          decisionReason: reason,
          departmentAssigned: departmentAssigned ?? item.departmentAssigned,
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void recordAssistanceSanction(
    String id, {
    required double amount,
    required String category,
    required String reviewerName,
    required String reviewerId,
  }) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Statutory Relief Sanction of ₹${amount.toStringAsFixed(0)} approved under $category by $reviewerName (ID: $reviewerId).';
        return item.copyWith(
          governmentAssistanceApproved: true,
          sanctionedAmountInr: amount,
          reliefAssistanceCategory: category,
          assistanceDeliveryStatus: 'SANCTIONED',
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void recordAssistanceDisbursal(String id, double amount, {required String bankRef}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Gratuitous relief benefit of ₹${amount.toStringAsFixed(0)} directly transferred via DBT to citizen account (Bank Ref: $bankRef).';
        return item.copyWith(
          assistanceDeliveredInr: amount,
          assistanceDeliveryStatus: 'DISBURSED',
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void recordAssistanceRejection(String id, {required String reason, required String reviewerName}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Relief claim reviewed and not sanctioned. Reason: $reason by $reviewerName.';
        return item.copyWith(
          governmentAssistanceApproved: false,
          assistanceDeliveryStatus: 'REJECTED',
          assistanceRejectionReason: reason,
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void reopenIncident(String id, String reason, String requesterName) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Reopened by $requesterName. Reason: $reason';
        return item.copyWith(
          status: IncidentStatus.underReview,
          escalatedTo: 'District Disaster Magistrate Review Desk',
          citizenReceiptDisputed: true,
          citizenDisputeReason: reason,
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void updateIncidentStatus(String id, IncidentStatus newStatus) {
    updateStatus(id, newStatus);
  }

  // D1. Food / Aid / Supply Requests Workflow
  bool acceptFoodAidRequest(String id, {required String acceptedBy, required String acceptedRole}) {
    bool accepted = false;
    state = state.map((item) {
      if (item.id == id) {
        if (item.acceptedBy != null && item.acceptedBy!.isNotEmpty) {
          return item;
        }
        accepted = true;
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Request accepted by [$acceptedRole] $acceptedBy. Mobilizing relief supply inventory.';
        return item.copyWith(
          acceptedBy: acceptedBy,
          acceptedRole: acceptedRole,
          status: IncidentStatus.helpAssigned,
          assistanceDeliveryStatus: 'ACCEPTED',
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
    return accepted;
  }

  void markFoodAidInTransit(String id, {required String courierOrVolunteer}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Consignment in transit with $courierOrVolunteer. GPS telemetry route dispatched.';
        return item.copyWith(
          status: IncidentStatus.inProgress,
          assistanceDeliveryStatus: 'IN_TRANSIT',
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void markFoodAidDelivered(String id, {required String deliveredBy}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Relief supplies delivered on scene by $deliveredBy. Awaiting citizen confirmation.';
        return item.copyWith(
          status: IncidentStatus.resolved,
          assistanceDeliveryStatus: 'DELIVERED',
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void verifyReceiptByCitizen(String id, {required bool confirmed, String? disputeReason, required String citizenName}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        if (confirmed) {
          final log = '$timestamp: Citizen $citizenName verified receipt of supplies. Case closed successfully.';
          return item.copyWith(
            citizenReceiptConfirmed: true,
            citizenReceiptDisputed: false,
            status: IncidentStatus.closed,
            assistanceDeliveryStatus: 'VERIFIED_RECEIVED',
            verificationHistory: [log, ...item.verificationHistory],
          );
        } else {
          final log = '$timestamp: CITIZEN DISPUTE: $citizenName reported NOT received. Reason: ${disputeReason ?? "Supplies not delivered"}. Reopening case.';
          return item.copyWith(
            citizenReceiptConfirmed: false,
            citizenReceiptDisputed: true,
            citizenDisputeReason: disputeReason,
            status: IncidentStatus.underReview,
            assistanceDeliveryStatus: 'DISPUTED',
            escalatedTo: 'NGO Lead & SDMA Incident Commander Desk',
            verificationHistory: [log, ...item.verificationHistory],
          );
        }
      }
      return item;
    }).toList();
  }

  // D2. Missing Persons Joint Verification
  void confirmMissingPersonFoundByCitizen(String id, {required String familyNotes}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final authorityDone = item.foundConfirmedByAuthority;
        final newStatus = authorityDone ? IncidentStatus.closed : IncidentStatus.resolved;
        final log = '$timestamp: Reporting family confirmed missing person FOUND safe. Notes: $familyNotes. ${authorityDone ? "Both parties verified: CASE CLOSED." : "Awaiting authority verification."}';
        return item.copyWith(
          foundConfirmedByCitizen: true,
          status: newStatus,
          assistanceDeliveryStatus: authorityDone ? 'PERSON_FOUND_VERIFIED' : 'CITIZEN_FOUND_CONFIRMED',
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void confirmMissingPersonFoundByAuthority(String id, {required String officerName, required String officerRole}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final citizenDone = item.foundConfirmedByCitizen;
        final newStatus = citizenDone ? IncidentStatus.closed : IncidentStatus.resolved;
        final log = '$timestamp: [$officerRole] $officerName verified missing person identity on scene. ${citizenDone ? "Both parties verified: CASE CLOSED." : "Awaiting family confirmation."}';
        return item.copyWith(
          foundConfirmedByAuthority: true,
          status: newStatus,
          assistanceDeliveryStatus: citizenDone ? 'PERSON_FOUND_VERIFIED' : 'AUTHORITY_FOUND_CONFIRMED',
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  // D3. Damage Claim -> Citizen Verification & Receipt
  void confirmCitizenClaimVerification(String id, {required String upiOrBankDetails}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final log = '$timestamp: Citizen verified statutory claim identity and confirmed payout account: $upiOrBankDetails.';
        return item.copyWith(
          citizenReceiptConfirmed: false,
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void confirmClaimReceiptByCitizen(String id, {required bool received, String? disputeReason}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        if (received) {
          final log = '$timestamp: Citizen confirmed ex-gratia bank credit received. Formal release certificate generated.';
          return item.copyWith(
            citizenReceiptConfirmed: true,
            citizenReceiptDisputed: false,
            status: IncidentStatus.closed,
            assistanceDeliveryStatus: 'DISBURSEMENT_VERIFIED',
            verificationHistory: [log, ...item.verificationHistory],
          );
        } else {
          final log = '$timestamp: CITIZEN DISPUTE: Ex-gratia funds not received in registered account. Dispute: ${disputeReason ?? "Bank credit not reflected"}. Sent to Finance audit.';
          return item.copyWith(
            citizenReceiptConfirmed: false,
            citizenReceiptDisputed: true,
            citizenDisputeReason: disputeReason,
            status: IncidentStatus.underReview,
            assistanceDeliveryStatus: 'DISBURSEMENT_DISPUTED',
            escalatedTo: 'State Disaster Response Fund Finance Directorate',
            verificationHistory: [log, ...item.verificationHistory],
          );
        }
      }
      return item;
    }).toList();
  }

  // D5. SOS Joint Confirmation
  void confirmSosRescuedByResponder(String id, {required String unitId}) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final citizenDone = item.sosRescuedConfirmedByCitizen;
        final newStatus = citizenDone ? IncidentStatus.closed : IncidentStatus.resolved;
        final log = '$timestamp: Rescue Unit $unitId arrived at coordinates and completed extraction. ${citizenDone ? "Both parties confirmed safe: SOS CLOSED." : "Awaiting citizen confirmation."}';
        return item.copyWith(
          sosRescuedConfirmedByResponder: true,
          status: newStatus,
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void confirmSosRescuedByCitizen(String id) {
    state = state.map((item) {
      if (item.id == id) {
        final timestamp = DateTime.now().toIso8601String().substring(0, 16);
        final responderDone = item.sosRescuedConfirmedByResponder;
        final newStatus = responderDone ? IncidentStatus.closed : IncidentStatus.resolved;
        final log = '$timestamp: Citizen confirmed safe extraction on scene. ${responderDone ? "Both parties confirmed: SOS CLOSED." : "Awaiting responder sign-off."}';
        return item.copyWith(
          sosRescuedConfirmedByCitizen: true,
          status: newStatus,
          verificationHistory: [log, ...item.verificationHistory],
        );
      }
      return item;
    }).toList();
  }

  void confirmDuplicate(String duplicateId, String masterId) {
    state = state.map((item) {
      if (item.id == duplicateId) {
        return item.copyWith(
          duplicateOfId: masterId,
          duplicateConfirmedByHuman: true,
          status: IncidentStatus.duplicate,
          verificationHistory: [
            '${DateTime.now().toIso8601String().substring(0, 16)}: Confirmed as duplicate of incident $masterId',
            ...item.verificationHistory,
          ],
        );
      }
      return item;
    }).toList();
  }

  void rejectDuplicate(String incidentId) {
    state = state.map((item) {
      if (item.id == incidentId) {
        return item.copyWith(
          isPossibleDuplicate: false,
          duplicateOfId: null,
          duplicateConfidence: 0.0,
          verificationHistory: [
            '${DateTime.now().toIso8601String().substring(0, 16)}: Marked as independent unique incident (AI duplicate candidate rejected)',
            ...item.verificationHistory,
          ],
        );
      }
      return item;
    }).toList();
  }

  void updateWhatIfSimulation(String id, Map<String, dynamic> simData, double adjustedScore) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(
          whatIfSimulation: simData,
          priorityScore: adjustedScore,
          priorityExplanation: 'Simulated What-If adjustment applied: ${simData['notes']}',
        );
      }
      return item;
    }).toList();
  }
}

final incidentsProvider = StateNotifierProvider<IncidentsNotifier, List<IncidentModel>>((ref) {
  return IncidentsNotifier();
});

final selectedIncidentProvider = StateProvider<IncidentModel?>((ref) {
  final list = ref.watch(incidentsProvider);
  return list.isNotEmpty ? list.first : null;
});

// Official Alerts Provider
final alertsProvider = StateProvider<List<AlertModel>>((ref) {
  return DemoDataService.getOfficialAlerts();
});

// Shelters Provider
class SheltersNotifier extends StateNotifier<List<ShelterModel>> {
  SheltersNotifier() : super(DemoDataService.getShelters());

  void updateOccupancy(String id, int newOccupancy) {
    state = state.map((shelter) {
      if (shelter.id == id) {
        return ShelterModel(
          id: shelter.id,
          name: shelter.name,
          address: shelter.address,
          latitude: shelter.latitude,
          longitude: shelter.longitude,
          totalCapacity: shelter.totalCapacity,
          occupiedBeds: newOccupancy.clamp(0, shelter.totalCapacity),
          waterLitersStock: shelter.waterLitersStock,
          foodMealsStock: shelter.foodMealsStock,
          hasMedicalUnit: shelter.hasMedicalUnit,
          lastUpdated: DateTime.now(),
          isCapacityStale: false,
        );
      }
      return shelter;
    }).toList();
  }
}

final sheltersProvider = StateNotifierProvider<SheltersNotifier, List<ShelterModel>>((ref) {
  return SheltersNotifier();
});

// Volunteers Provider
class VolunteersNotifier extends StateNotifier<List<VolunteerModel>> {
  VolunteersNotifier() : super(DemoDataService.getVolunteers());

  void assignVolunteer(String volunteerId, String incidentId) {
    state = state.map((v) {
      if (v.id == volunteerId) {
        return VolunteerModel(
          id: v.id,
          name: v.name,
          phoneMasked: v.phoneMasked,
          skills: v.skills,
          latitude: v.latitude,
          longitude: v.longitude,
          district: v.district,
          isAvailable: false,
          isVerified: v.isVerified,
          matchedIncidentId: incidentId,
        );
      }
      return v;
    }).toList();
  }
}

final volunteersProvider = StateNotifierProvider<VolunteersNotifier, List<VolunteerModel>>((ref) {
  return VolunteersNotifier();
});

// Rumors Provider
class RumorsNotifier extends StateNotifier<List<RumorModel>> {
  RumorsNotifier() : super(DemoDataService.getRumors());

  void updateRumorStatus(String id, RumorStatus newStatus, String factCheckNote) {
    state = state.map((r) {
      if (r.id == id) {
        return RumorModel(
          id: r.id,
          claimText: r.claimText,
          sourceChannel: r.sourceChannel,
          reportedRegion: r.reportedRegion,
          reportsCount: r.reportsCount,
          status: newStatus,
          officialFactCheck: factCheckNote,
          firstReported: r.firstReported,
          lastUpdated: DateTime.now(),
        );
      }
      return r;
    }).toList();
  }
}

final rumorsProvider = StateNotifierProvider<RumorsNotifier, List<RumorModel>>((ref) {
  return RumorsNotifier();
});

// AI Feedback Loop Audit Record
class AiFeedbackRecord {
  final String targetId;
  final String featureName; // PriorityScore, DuplicateCandidate, FloodRisk
  final String rating; // 'CORRECT', 'INCORRECT', 'UNCERTAIN'
  final String? comments;
  final DateTime recordedAt;

  AiFeedbackRecord({
    required this.targetId,
    required this.featureName,
    required this.rating,
    this.comments,
    required this.recordedAt,
  });
}

class AiFeedbackNotifier extends StateNotifier<List<AiFeedbackRecord>> {
  AiFeedbackNotifier() : super([]);

  void recordFeedback(String targetId, String feature, String rating, {String? comments}) {
    state = [
      AiFeedbackRecord(
        targetId: targetId,
        featureName: feature,
        rating: rating,
        comments: comments,
        recordedAt: DateTime.now(),
      ),
      ...state,
    ];
  }
}

final aiFeedbackProvider = StateNotifierProvider<AiFeedbackNotifier, List<AiFeedbackRecord>>((ref) {
  return AiFeedbackNotifier();
});

// Offline Draft Queue
final offlineDraftsProvider = StateProvider<List<IncidentModel>>((ref) => []);
