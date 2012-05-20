var TONE_POS_FOR_NOTE = {
    C: 0,
    "C#": 1, "Db": 1,
    D: 2,
    "D#": 3, "Eb": 3,
    "E": 4,
    "F": 5,
    "F#": 6, "Gb": 6,
    "G": 7,
    "G#": 8, "Ab": 8,
    "A": 9,
    "A#": 10, "Bb": 10,
    "B": 11
}
var OCTAVE_LENGTH = 12;
var MIDI_BASE = 12;

var getMidiNo = function(note) {
    note = note.toUpperCase();
    var i = note.length - 1;
    var octave = parseInt(note.charAt(i));
    var pos = TONE_POS_FOR_NOTE[note.substr(0, i)];
    return (OCTAVE_LENGTH * octave) + MIDI_BASE + pos;
};

var endTime = function (time, expr) {
    if (expr.tag === 'note' || expr.tag === 'rest') {
        return time + expr.dur;
    }
    if (expr.tag === 'seq') {
        return endTime(endTime(time, expr.left), expr.right);
    }
    if (expr.tag === 'par') {
        return Math.max(endTime(time, expr.left), endTime(time, expr.right));
    }
    if (expr.tag === 'repeat') {
        return time + (expr.count * endTime(0, expr.section));
    }
    throw 'Unhandled tag: ' + expr.tag;
        
};

var getNotes = function(startTime, me) {
    var startOfRight;
    if (me.tag === 'note') {
        return [{
            tag: 'note',
            pitch: getMidiNo(me.pitch),
            start: startTime,
            dur: me.dur
        }];
    }
    if (me.tag === 'rest') {
        return [{
            tag: 'rest', start: startTime, dur: me.dur
        }];
    }
    if (me.tag === 'seq') {
        startOfRight = endTime(startTime, me.left);
        return getNotes(startTime, me.left)
                .concat(getNotes(startOfRight, me.right));
    }
    if (me.tag === 'par') {
        return getNotes(startTime, me.left)
                .concat(getNotes(startTime, me.right));
    }
    if (me.tag === 'repeat') {
        var notes = [];
        var nextStart = startTime;
        for (var i = me.count; i > 0; i--) {
            notes = notes.concat(getNotes(nextStart, me.section));
            nextStart = endTime(nextStart, me.section);
        }
        return notes;
    }
    throw "Unhandled tag: " + me.tag;
};

var compile = function (musexpr) {
    var startTime = 0;
    return getNotes(startTime, musexpr);
};

var melody_mus = 
    { tag: 'seq',
      left: { tag: 'repeat',
         section: { tag: 'seq',
            left: { tag: 'note', pitch: 'a4', dur: 250 },
            right: { tag: 'note', pitch: 'b4', dur: 250 } },
         count: 3
      },
      right:
       { tag: 'seq',
         left: { tag: 'rest', dur: 250 },
         right: { tag: 'seq',
           left: { tag: 'note', pitch: 'c4', dur: 500 },
           right: { tag: 'note', pitch: 'd4', dur: 500 } } } };

console.log(melody_mus);
console.log(compile(melody_mus));
