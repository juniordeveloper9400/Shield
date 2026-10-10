import 'package:shield/module/agent/agent_phone_verifier.dart';
import 'package:shield/module/auth/auth_service.dart';

/// In-memory stand-in for [BackendAgentOtpTransport] so widget tests can
/// drive the agent-registration phone check without a live backend.
///
/// Inject it in `setUp` with
/// `AgentPhoneVerifier.instance.useTransport(FakeAgentOtpTransport())`, then
/// enter [FakeAgentOtpTransport.code] (same value as [AuthService.demoOtp])
/// on the OTP step.
class FakeAgentOtpTransport implements AgentOtpTransport {
  /// The one code [confirmCode] treats as correct — matches
  /// [AuthService.otpLength] (4).
  static const String code = '1234';

  bool _sent = false;

  /// How many codes [sendCode] has been asked to send.
  int codesSent = 0;

  @override
  Future<AgentOtpOutcome> sendCode(String e164Phone) async {
    _sent = true;
    codesSent++;
    return const AgentOtpOutcome.success();
  }

  @override
  Future<AgentOtpOutcome> confirmCode(String e164Phone, String otp) async {
    if (!_sent) {
      return const AgentOtpOutcome.failed(OtpError.noPendingRequest);
    }
    return otp == code
        ? const AgentOtpOutcome.success()
        : const AgentOtpOutcome.failed(OtpError.wrongOtp);
  }
}
