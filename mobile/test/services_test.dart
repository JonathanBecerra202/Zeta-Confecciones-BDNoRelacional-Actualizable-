import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeta_confecciones_mobile/core/api_client.dart';
import 'package:zeta_confecciones_mobile/repositories/repo.dart';
import 'package:zeta_confecciones_mobile/services/auth_service.dart';
import 'package:zeta_confecciones_mobile/services/avatar_service.dart';
import 'package:zeta_confecciones_mobile/services/user_admin_service.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _user = {
  'user_id': 'ba9397f7-3cb4-4a4a-9f7b-eb48467041fb',
  'email': 'admin@zetaconfecciones.com',
  'full_name': 'Administrador Zeta',
  'role': 'Admin',
  'active': true,
  'must_change_password': false,
  'avatar_path': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ApiClient', () {
    test('envía el token Bearer y parsea JSON', () async {
      late http.Request seen;
      final api = ApiClient.forTesting(client: MockClient((req) async {
        seen = req;
        return _json({'ok': true});
      }));
      await api.setToken('abc123');
      final data = await api.get('/health', query: {'a': 1, 'b': null});
      expect(data, {'ok': true});
      expect(seen.headers['Authorization'], 'Bearer abc123');
      expect(seen.url.toString(), 'http://test/health?a=1');
    });

    test('persiste y borra el token', () async {
      final api = ApiClient.forTesting(client: MockClient((_) async => _json({})));
      await api.setToken('t1');
      expect((await SharedPreferences.getInstance()).getString('zeta_access_token'), 't1');
      await api.setToken(null);
      expect((await SharedPreferences.getInstance()).getString('zeta_access_token'), isNull);
      expect(api.token, isNull);
    });

    test('init restaura el token guardado', () async {
      SharedPreferences.setMockInitialValues({'zeta_access_token': 'guardado'});
      final api = ApiClient.forTesting(client: MockClient((_) async => _json({})));
      await api.init();
      expect(api.token, 'guardado');
    });

    test('errores usan el campo detail', () async {
      final api = ApiClient.forTesting(
          client: MockClient((_) async => _json({'detail': 'No autorizado'}, 401)));
      expect(
        () => api.get('/x'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.message, 'message', 'No autorizado')),
      );
    });

    test('errores de validación (lista) usan msg', () async {
      final api = ApiClient.forTesting(
          client: MockClient((_) async => _json({'detail': [{'msg': 'campo requerido'}]}, 422)));
      expect(() => api.post('/x', body: {}),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', 'campo requerido')));
    });

    test('204 devuelve null y resolveUrl arma URLs', () async {
      final api = ApiClient.forTesting(client: MockClient((_) async => http.Response('', 204)));
      expect(await api.delete('/orders/1'), isNull);
      expect(api.resolveUrl('/static/a.jpg'), 'http://test/static/a.jpg');
      expect(api.resolveUrl('https://otro/x.jpg'), 'https://otro/x.jpg');
    });
  });

  group('AuthService', () {
    test('signIn guarda token y estado de sesión', () async {
      late http.Request seen;
      final api = ApiClient.forTesting(client: MockClient((req) async {
        seen = req;
        return _json({'access_token': 'jwt', 'token_type': 'bearer', 'user': _user});
      }));
      final auth = AuthService(api);
      await auth.signIn(email: ' admin@zetaconfecciones.com ', password: 'Admin1234!');
      expect(jsonDecode(seen.body)['email'], 'admin@zetaconfecciones.com');
      expect(api.token, 'jwt');
      expect(auth.currentUserId, _user['user_id']);
      expect(auth.mustChangePassword, isFalse);
    });

    test('signIn con credenciales malas lanza ApiException', () async {
      final api = ApiClient.forTesting(
          client: MockClient((_) async => _json({'detail': 'Correo o contraseña incorrectos.'}, 401)));
      expect(() => AuthService(api).signIn(email: 'a@b.com', password: 'x'),
          throwsA(isA<ApiException>()));
    });

    test('restoreSession sin token devuelve null', () async {
      final api = ApiClient.forTesting(client: MockClient((_) async => _json(_user)));
      expect(await AuthService(api).restoreSession(), isNull);
    });

    test('restoreSession con token válido devuelve el user_id', () async {
      final api = ApiClient.forTesting(client: MockClient((_) async => _json(_user)));
      await api.setToken('jwt');
      expect(await AuthService(api).restoreSession(), _user['user_id']);
    });

    test('restoreSession con 401 borra el token', () async {
      final api = ApiClient.forTesting(
          client: MockClient((_) async => _json({'detail': 'expirado'}, 401)));
      await api.setToken('viejo');
      expect(await AuthService(api).restoreSession(), isNull);
      expect(api.token, isNull);
    });

    test('contraseña temporal marca mustChangePassword', () async {
      final api = ApiClient.forTesting(client: MockClient((_) async => _json({
            'access_token': 'jwt',
            'user': {..._user, 'must_change_password': true},
          })));
      final auth = AuthService(api);
      await auth.signIn(email: 'a@b.com', password: 'x');
      expect(auth.mustChangePassword, isTrue);
    });

    test('changePassword con 400 lanza WrongCurrentPasswordException', () async {
      final api = ApiClient.forTesting(
          client: MockClient((_) async => _json({'detail': 'La contraseña actual no es correcta.'}, 400)));
      expect(() => AuthService(api).changePassword(currentPassword: 'x', newPassword: 'Nueva1234'),
          throwsA(isA<WrongCurrentPasswordException>()));
    });

    test('completeTemporaryPasswordChange limpia la marca', () async {
      var calls = 0;
      final api = ApiClient.forTesting(client: MockClient((req) async {
        calls++;
        if (req.url.path == '/auth/login') {
          return _json({'access_token': 'jwt', 'user': {..._user, 'must_change_password': true}});
        }
        return http.Response('', 204);
      }));
      final auth = AuthService(api);
      await auth.signIn(email: 'a@b.com', password: 'x');
      expect(auth.mustChangePassword, isTrue);
      await auth.completeTemporaryPasswordChange('Nueva1234');
      expect(auth.mustChangePassword, isFalse);
      expect(calls, 2);
    });

    test('signOut borra token y sesión', () async {
      final api = ApiClient.forTesting(
          client: MockClient((_) async => _json({'access_token': 'jwt', 'user': _user})));
      final auth = AuthService(api);
      await auth.signIn(email: 'a@b.com', password: 'x');
      await auth.signOut();
      expect(api.token, isNull);
      expect(auth.currentUserId, isNull);
    });
  });

  group('UserAdminService', () {
    test('listUsers arma la query y parsea la página', () async {
      late Uri url;
      final api = ApiClient.forTesting(client: MockClient((req) async {
        url = req.url;
        return _json({
          'users': [
            {
              'user_id': 'u1',
              'email': 'a@b.com',
              'full_name': 'Ana',
              'role': 'Employee',
              'active': true,
              'must_change_password': true,
              'created_at': '2026-11-25T14:35:55Z',
              'avatar_path': null,
            }
          ],
          'total': 11,
        });
      }));
      final page = await UserAdminService(api)
          .listUsers(search: ' ana ', role: 'Employee', includeInactive: true, page: 1, pageSize: 5);
      expect(url.path, '/admin/users');
      expect(url.queryParameters, {
        'search': 'ana',
        'role': 'Employee',
        'include_inactive': 'true',
        'page': '1',
        'page_size': '5',
      });
      expect(page.total, 11);
      expect(page.users.single.mustChangePassword, isTrue);
    });

    test('createUser devuelve el user_id', () async {
      late http.Request seen;
      final api = ApiClient.forTesting(client: MockClient((req) async {
        seen = req;
        return _json({..._user, 'user_id': 'nuevo-id'}, 201);
      }));
      final id = await UserAdminService(api).createUser(
        email: 'n@b.com',
        password: 'Temporal123',
        fullName: 'Nuevo',
        role: 'Employee',
      );
      expect(id, 'nuevo-id');
      expect(seen.method, 'POST');
      expect(jsonDecode(seen.body)['role'], 'Employee');
    });

    test('updateUser y setPassword usan los endpoints correctos', () async {
      final seen = <String>[];
      final api = ApiClient.forTesting(client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        return req.method == 'PATCH' ? _json(_user) : http.Response('', 204);
      }));
      final svc = UserAdminService(api);
      await svc.updateUser('u1', active: false);
      await svc.setPassword('u1', 'Temporal123');
      expect(seen, ['PATCH /admin/users/u1', 'POST /admin/users/u1/password']);
    });
  });

  group('AvatarService', () {
    test('contentTypeFor', () {
      expect(AvatarService.contentTypeFor(mime: 'image/png', fileName: 'x'), 'image/png');
      expect(AvatarService.contentTypeFor(fileName: 'foto.JPG'), 'image/jpeg');
      expect(AvatarService.contentTypeFor(fileName: 'foto.gif'), isNull);
      expect(AvatarService.contentTypeFor(fileName: 'sinextension'), isNull);
    });

    test('upload rechaza imágenes de más de 2 MB', () async {
      final api = ApiClient.forTesting(client: MockClient((_) async => _json({})));
      expect(
        () => AvatarService(api)
            .upload('u1', Uint8List(AvatarService.maxBytes + 1), 'image/png'),
        throwsException,
      );
    });

    test('upload envía multipart y devuelve la ruta', () async {
      late http.BaseRequest seen;
      final api = ApiClient.forTesting(client: MockClient.streaming((req, body) async {
        seen = req;
        await body.drain<void>();
        final bytes = utf8.encode(jsonEncode({
          'avatar_path': '/static/avatars/u1/avatar.png',
          'avatar_url': '/static/avatars/u1/avatar.png',
        }));
        return http.StreamedResponse(Stream.value(bytes), 200,
            headers: {'content-type': 'application/json'});
      }));
      final path = await AvatarService(api).upload('u1', Uint8List.fromList([1, 2, 3]), 'image/png');
      expect(path, '/static/avatars/u1/avatar.png');
      expect(seen.method, 'POST');
      expect(seen.url.path, '/users/u1/avatar');
    });

    test('remove usa DELETE y signedUrls resuelve contra el backend', () async {
      String? seen;
      final api = ApiClient.forTesting(client: MockClient((req) async {
        seen = '${req.method} ${req.url.path}';
        return http.Response('', 204);
      }));
      final svc = AvatarService(api);
      await svc.remove('u1');
      expect(seen, 'DELETE /users/u1/avatar');
      expect(await svc.signedUrls(['/static/avatars/u1/avatar.png']),
          {'/static/avatars/u1/avatar.png': 'http://test/static/avatars/u1/avatar.png'});
      expect(await svc.signedUrls([]), isEmpty);
    });
  });

  group('Repo', () {
    Repo repoWith(Future<http.Response> Function(http.Request) handler) =>
        Repo(ApiClient.forTesting(client: MockClient(handler)));

    test('orders parsea paid y delivery_date', () async {
      final repo = repoWith((_) async => _json([
            {
              'garment_order_id': 1,
              'description': 'Bata',
              'total_price': 90000.0,
              'amount_paid': 90000.0,
              'balance_due': 0.0,
              'status': 'Pending',
              'paid': true,
              'created_at': '2026-11-25T14:35:55Z',
              'delivery_date': '2026-12-01',
              'quantity': 2,
              'unit_price': 45000.0,
              'embroidery': true,
              'client_id': 1,
              'measurement_id': 1,
            }
          ]));
      final orders = await repo.orders();
      expect(orders.single.paid, isTrue);
      expect(orders.single.deliveryDate, '2026-12-01');
    });

    test('createMeasurement usa /clients/{id}/measurements sin client_id en el body', () async {
      late http.Request seen;
      final repo = repoWith((req) async {
        seen = req;
        return _json({}, 201);
      });
      await repo.createMeasurement({'client_id': 3, 'back_width_ae': 40, 'notes': 'x'});
      expect(seen.url.path, '/clients/3/measurements');
      expect(jsonDecode(seen.body), {'back_width_ae': 40, 'notes': 'x'});
    });

    test('createPayment y deletePayment', () async {
      final seen = <String>[];
      final repo = repoWith((req) async {
        seen.add('${req.method} ${req.url.path}');
        return req.method == 'POST' ? _json({}, 201) : http.Response('', 204);
      });
      await repo.createPayment(orderId: 4, amount: 5000, note: 'cuota');
      await repo.deletePayment(9);
      expect(seen, ['POST /orders/4/payments', 'DELETE /payments/9']);
    });

    test('currentProfile lee /auth/me', () async {
      final repo = repoWith((_) async => _json(_user));
      final p = await repo.currentProfile();
      expect(p.isAdmin, isTrue);
      expect(p.fullName, 'Administrador Zeta');
    });

    test('auditPage sin usuarios ni sistema no llama al servidor', () async {
      var called = false;
      final repo = repoWith((_) async {
        called = true;
        return _json({'rows': [], 'total': 0});
      });
      final r = await repo.auditPage(page: 0, userIds: const []);
      expect(r.total, 0);
      expect(called, isFalse);
    });

    test('auditPage manda filtros y parsea before/after', () async {
      late Uri url;
      final repo = repoWith((req) async {
        url = req.url;
        return _json({
          'rows': [
            {
              'audit_log_id': 1,
              'table_name': 'client',
              'operation': 'UPDATE',
              'record_id': '1',
              'before': {'a': 1},
              'after': {'a': 2},
              'logged_at': '2026-11-25T14:35:55+00:00',
              'user_id': 'u1',
            }
          ],
          'total': 21,
        });
      });
      final r = await repo.auditPage(page: 2, operation: 'UPDATE', userIds: ['u1', 'u2']);
      expect(url.path, '/audit');
      expect(url.queryParametersAll['user_ids'], ['u1', 'u2']);
      expect(url.queryParameters['operation'], 'UPDATE');
      expect(url.queryParameters['page'], '2');
      expect(r.total, 21);
      expect(r.rows.single.after, {'a': 2});
    });

    test('userNames', () async {
      final repo = repoWith((_) async => _json([
            {'user_id': 'u1', 'full_name': 'Ana'},
          ]));
      final names = await repo.userNames();
      expect(names.single.fullName, 'Ana');
    });
  });
}
