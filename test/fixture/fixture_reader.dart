import 'dart:convert';
import 'dart:io';

String fixture(String name) => File('test/fixture/$name').readAsStringSync();

Map<String, dynamic> fixtureJson(String name) => jsonDecode(fixture(name)) as Map<String, dynamic>;
