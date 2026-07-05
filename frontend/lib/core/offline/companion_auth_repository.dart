import 'package:anvil_foundry/anvil_foundry.dart';

/// Auth repository that allows offline entry when stored tokens exist.
class CompanionAuthRepository extends AuthRepositoryService {
  CompanionAuthRepository(
    AuthTokenProviderService tokenProvider,
    HttpClientServiceBase http, {
    AuthApiConfig authApiConfig = AuthApiConfig.companion,
  })  : _tokenProvider = tokenProvider,
        super(tokenProvider, http, authApiConfig: authApiConfig);

  final AuthTokenProviderService _tokenProvider;

  @override
  Future<bool> isAuthenticated() async {
    try {
      return await super.isAuthenticated().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw AuthException.networkError('Authentication check timed out');
        },
      );
    } on AuthException catch (error) {
      if (error.code == AuthErrorCode.networkError) {
        return _hasStoredToken();
      }
      return false;
    } catch (_) {
      return _hasStoredToken();
    }
  }

  Future<bool> _hasStoredToken() async {
    try {
      final token = await _tokenProvider.getAccessToken();
      return token.isNotEmpty;
    } on AuthException {
      return false;
    }
  }
}
