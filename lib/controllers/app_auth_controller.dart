import 'dart:io';
import 'package:auth/models/response_model.dart';
import 'package:auth/models/user.dart';
import 'package:auth/utils/app_response.dart';
import 'package:auth/utils/app_utils.dart';
import 'package:conduit/conduit.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AppAuthController extends ResourceController {
  final ManagedContext managedContext;

  AppAuthController(this.managedContext);

  @Operation.post()
  Future<Response> signIn(@Bind.body() User user) async {
    if (user.password == null || user.username == null) {
      return Response.badRequest(
          body: ResponseModel(
        message: 'Filds username and password are requiered!',
      ));
    }

    try {
      final qFindUser = Query<User>(managedContext)
        ..where((table) => table.username).equalTo(user.username)
        ..returningProperties(
          (table) => [
            table.id,
            table.salt,
            table.hashPassword,
          ],
        );
      final findUser = await qFindUser.fetchOne();
      if (findUser == null) {
        throw QueryException.input('User not found', []);
      }
      final requestHasPassword = AuthUtility.generatePasswordHash(
        user.password ?? '',
        findUser.salt ?? '',
      );

      if (requestHasPassword == findUser.hashPassword) {
        await _updateTokens(findUser.id ?? -1, managedContext);
        final newUser =
            await managedContext.fetchObjectWithID<User>(findUser.id);
        return AppResponse.ok(
          body: newUser?.backing.contents,
          message: 'Successful authorization',
        );
      } else {
        throw QueryException.input('Ivalide password', []);
      }
    } catch (error) {
      return AppResponse.serverError(error, message: 'Fail authorization');
    }
  }

  @Operation.put()
  Future<Response> signUp(@Bind.body() User user) async {
    if (user.password == null || user.username == null || user.email == null) {
      return Response.badRequest(
          body: ResponseModel(
        message: 'Filds username, password and email are requiered!',
      ));
    }

    final salt = AuthUtility.generateRandomSalt();
    final hashPassword =
        AuthUtility.generatePasswordHash(user.password ?? '', salt);

    try {
      late final int id;
      managedContext.transaction((transaction) async {
        final qCreateUser = Query<User>(transaction)
          ..values.username = user.username
          ..values.email = user.email
          ..values.salt = salt
          ..values.hashPassword = hashPassword;

        final createUser = await qCreateUser.insert();
        id = createUser.asMap()['id'];
        await _updateTokens(id, transaction);
        return null;
      });
      final userData = await managedContext.fetchObjectWithID<User>(id);
      return AppResponse.ok(
        body: userData?.backing.contents,
        message: 'Successful registration',
      );
    } catch (error) {
      return AppResponse.serverError(error, message: 'Fail registration');
    }
  }

  @Operation.post('refresh')
  Future<Response> refreshToken(
      @Bind.path('refresh') String refreshToken) async {
    try {
      final id = AppUtils.getIdFromToken(refreshToken);
      final user = await managedContext.fetchObjectWithID<User>(id);
      if (user?.refreshToken != refreshToken) {
        return Response.unauthorized(
            body: ResponseModel(message: 'Token is not valide!'));
      } else {
        await _updateTokens(id, managedContext);
        final user = await managedContext.fetchObjectWithID<User>(id);
        return Response.ok(ResponseModel(
          data: user?.backing.contents,
          message: 'Successful update tokens',
        ));
      }
    } catch (error) {
      return AppResponse.serverError(error, message: 'Fail update tokens');
    }
  }

  Map<String, dynamic> _getTokens(int id) {
    //TODO: remove when will be release
    final key = Platform.environment['SECRET_KEY'] ?? 'SECRET_KEY';
    final accessClaimSet =
        JwtClaim(maxAge: Duration(hours: 1), otherClaims: {'id': id});
    final refreshClaimSet = JwtClaim(otherClaims: {'id': id});
    final token = <String, dynamic>{
      'access': issueJwtHS256(accessClaimSet, key),
      'refresh': issueJwtHS256(refreshClaimSet, key),
    };
    return token;
  }

  Future<void> _updateTokens(int id, ManagedContext transaction) async {
    final Map<String, dynamic> tokens = _getTokens(id);
    final qUpdateTokens = Query<User>(transaction)
      ..where((user) => user.id).equalTo(id)
      ..values.accessToken = tokens['access']
      ..values.refreshToken = tokens['refresh'];
    await qUpdateTokens.updateOne();
  }
}
