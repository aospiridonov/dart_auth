import 'package:auth/models/response_model.dart';
import 'package:conduit/conduit.dart';

class AppAuthController extends ResourceController {
  final ManagedContext managedContext;

  AppAuthController(this.managedContext);

  @Operation.post()
  Future<Response> signIn() async => Response.ok(
        ResponseModel(
          data: {
            'id': '1',
            'refreshToken': 'refreshToken',
            'accessToken': 'accessToken',
          },
          message: 'signIn ok',
        ).toJson(),
      );

  @Operation.put()
  Future<Response> signUp() async => Response.ok(
        ResponseModel(
          data: {
            'id': '1',
            'refreshToken': 'refreshToken',
            'accessToken': 'accessToken',
          },
          message: 'signUp ok',
        ).toJson(),
      );

  @Operation.post('refresh')
  Future<Response> refreshToken() async => Response.unauthorized(
      body: ResponseModel(error: 'token is not valid').toJson());
}
