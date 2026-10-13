-- Bone Gnaw, Cannibalize and Make Camp are copies of 20577. That spell is a dummy:
-- the eat channel, the progress bar and the heal are spell 20578, cast by spell_gen_cannibalize.
-- Without the script the copy succeeds and does nothing.
INSERT IGNORE INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(14000512, 'spell_gen_cannibalize'),
(14000742, 'spell_gen_cannibalize'),
(14000832, 'spell_gen_cannibalize');
