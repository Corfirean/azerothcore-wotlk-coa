-- Hidden dummy the classic talent Reset button casts (CastSpellByID).
-- ConfirmTalentWipe only works after a trainer, so it never sent a packet.
CREATE TEMPORARY TABLE `tmp_coa_reset` LIKE `spell_dbc`;
DELETE FROM `tmp_coa_reset`;
INSERT INTO `tmp_coa_reset` SELECT * FROM `spell_dbc` WHERE `ID` = 14000832 LIMIT 1;
UPDATE `tmp_coa_reset` SET
  `ID` = 14009999,
  Attributes = 144,
  AttributesEx = 0,
  AttributesEx2 = 0,
  Targets = 0,
  TargetCreatureType = 0,
  RecoveryTime = 0,
  DurationIndex = 0,
  RangeIndex = 1,
  ChannelInterruptFlags = 0,
  ProcTypeMask = 0,
  Effect_1 = 3,
  Effect_2 = 0,
  Effect_3 = 0,
  ImplicitTargetA_1 = 1,
  ImplicitTargetA_2 = 0,
  ImplicitTargetA_3 = 0,
  ImplicitTargetB_1 = 0,
  ImplicitTargetB_2 = 0,
  ImplicitTargetB_3 = 0,
  EffectAura_1 = 0,
  EffectAura_2 = 0,
  SpellVisualID_1 = 0,
  SpellVisualID_2 = 0,
  Name_Lang_enUS = 'Reset Talents',
  NameSubtext_Lang_enUS = '',
  Description_Lang_enUS = 'Reset all talent points.';
DELETE FROM `spell_dbc` WHERE `ID` = 14009999;
INSERT INTO `spell_dbc` SELECT * FROM `tmp_coa_reset`;
DROP TABLE `tmp_coa_reset`;

INSERT IGNORE INTO `spell_script_names` (`spell_id`, `ScriptName`)
VALUES (14009999, 'spell_coa_free_talent_reset');
