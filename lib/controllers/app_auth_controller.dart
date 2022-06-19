import 'dart:io';
import 'package:auth/models/response_model.dart';
import 'package:auth/models/user.dart';
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
        message: "Filds username and password are requiered!",
      ));
    }

    final User fetchedUser = User();
    //connect to DB
    //find user
    //check password
    //fetch user

    return Response.ok(
      ResponseModel(
        data: {
          'id': fetchedUser.id,
          'refreshToken': fetchedUser.refreshToken,
          'accessToken': fetchedUser.accessToken,
        },
        message: 'Successful authorization',
      ).toJson(),
    );
  }

  @Operation.put()
  Future<Response> signUp(@Bind.body() User user) async {
    if (user.password == null || user.username == null || user.email == null) {
      return Response.badRequest(
          body: ResponseModel(
        message: "Filds username, password and email are requiered!",
      ));
    }

    final salt = AuthUtility.generateRandomSalt();
    final hashPassword =
        AuthUtility.generatePasswordHash(user.password ?? "", salt);

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
        final tokens = _getToken(id);
        final qUpdateTokens = Query<User>(transaction)
          ..where((user) => user.id).equalTo(id)
          ..values.accessToken = tokens['access']
          ..values.refreshToken = tokens['refresh'];
        await qUpdateTokens.updateOne();
        return null;
      });
      final userData = await managedContext.fetchObjectWithID<User>(id);
      return Response.ok(
        ResponseModel(
          data: userData?.backing.contents,
          message: 'Successful registration',
        ),
      );
    } on QueryException catch (error) {
      return Response.serverError(body: ResponseModel(message: error.message));
    }
  }

  @Operation.post('refresh')
  Future<Response> refreshToken(
      @Bind.path("refresh") String refreshToken) async {
    final User fetchedUser = User();

    //connect to DB
    //find user
    //check token
    //fetch user
    return Response.ok(
      ResponseModel(
        data: {
          'id': fetchedUser.id,
          'refreshToken': fetchedUser.refreshToken,
          'accessToken': fetchedUser.accessToken,
        },
        message: 'Successful update tokens',
      ).toJson(),
    );
  }

  Map<String, dynamic> _getToken(int id) {
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
}
