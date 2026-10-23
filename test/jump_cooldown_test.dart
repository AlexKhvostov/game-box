import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_world.dart';

GameWorld world(double cooldown) => GameWorld(
  config: GameplayConfig(game: GameConfig(jumpCooldownSec: cooldown)),
  field: const Size(380,380),
)..resetLayout();

void main(){
  test('zero has no additional wait but cannot restart a jump in mid-air',(){
    final w=world(0);
    expect(w.jumpCooldownMs,0);
    expect(w.jumpCooldownProgress(nowMs:0),1);
    expect(w.tryJump(nowMs:0),isTrue);
    final duration=w.jumpRemaining;
    expect(w.jumpCooldownRemaining(nowMs:0),0);
    expect(w.jumpCooldownProgress(nowMs:0).isFinite,isTrue);
    expect(w.tryJump(nowMs:0),isFalse);
    expect(w.jumpRemaining,duration);
    w.tickJump(duration);
    expect(w.tryJump(nowMs:duration*1000),isTrue);
  });
  for(final seconds in [0.1,0.5,1.0,2.0,10.0,20.0,30.0,60.0]){
    test('cooldown $seconds seconds respects its exact boundary and finite progress',(){
      final w=world(seconds),ms=seconds*1000;
      expect(w.tryJump(nowMs:0),isTrue);
      expect(w.jumpCooldownMs,ms);
      expect(w.jumpCooldownProgress(nowMs:ms/2),closeTo(.5,1e-9));
      w.tickJump(10);
      expect(w.tryJump(nowMs:ms-0.01),isFalse);
      expect(w.tryJump(nowMs:ms),isTrue);
      w.resetLayout();
      expect(w.jumpCooldownProgress(nowMs:0),1);
    });
  }
  for(final seconds in [0,0.1,1,2,20,30,60]){
    test('Android startup accepts $seconds without replacing zero with the default',(){
      final raw=jsonDecode(File(AndroidFirebaseConfig.assetPath).readAsStringSync()) as Map<String,dynamic>;
      raw['config']['game']['jumpCooldownSec']=seconds;
      raw['revision']=sha256.convert(utf8.encode(jsonEncode(raw['config']))).toString();
      expect(AndroidFirebaseConfig.parse(jsonEncode(raw),'jump-test').gameplay.jumpCooldownSec,seconds);
    });
  }
}
