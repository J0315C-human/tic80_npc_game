



## NPC scripting system

NPC scripts are made up of a list of commands.
Commands have this format:

`<time> <name> <verb> <param list>` 

`<time>` can be specified as:
  - a frame number: `421 bob jump`
  - a time tag: `X bob jump`
  - relative to before a time tag: `X-60 bob jump`
  - relative to after a time tag: `X+120 bob jump`

`<name>` is a name of an NPC present in this Scene

`<verb>` an NPC verb specified below

`<param list>` can be variable in length and type:
- empty (i.e. the command ends with the verb)
- a location (see below)
- a string (for the `say` verb)

### Location formats

Locations can be specified in these ways:

- an absolute x/y coordinate: `1 bob run 450 120`
- a coordinate with the X relative to the NPC's current position: `1 bob run +10 50`
- a coordinate with the Y relative to the NPC's current position: `2 bob run 0 -30`
- both coordinates relative: `1 bob walk -50 +0`
- the location of another NPC, given by name. For bob to walk to sue's position: `1 bob walk sue`
- a coordinate relative to another NPC's location: `1 bob walk sue +0 +30`
- name of a tagged location: `0 bob run stage_left`
- relative to a tagged location: `0 bob run stage_left +30 +5` (see location tagging below)

### NPC Verbs

These verbs available for NPCs:

- `to` - move to a location instantly
- `walk` - walk to a location
- `run` - run to a location
- `say` - talk
  - param: a string for the character to say
- `face` - face in a direction.
  - param: `left`, `right`, or the name of another NPC to face towards them.
- `jump` - jump
- `wave` - wave
- `gesture` - hold both arms up
- `point` - point in the direction they're facing
- `stop` - call off any current commands

### Time tagging:

To give a name to a frame number, use this syntax (with the hyphen): 

```- <tagname> tag <time>```

The tag time can be in any of the time formats above. This makes it easy to "slide" timeline events back and forth in groups.

Note that a time tag should be introduced before it is used in the script, so you might want to leave them all at the top.

### Location tagging:

To save a location as a tag, use this syntax:

```- <tagname> place <location>```

The location can be absolute or relative to another location tag.

Note that these should also be placed before they are used in the script.

### Stage commands:

Stage commands take the same format as NPC commands, but instead of an NPC name, just use a hyphen ( - ).

Verbs for stage commands include:
- `to` - move stage focal point to a location instantly
- `slowpan` - slowly pan to a location
- `pan` - pan to a location at medium-speed

all of these use a 'location' parameter, which can be any of the location formats. Note that the center of the screen is what will be panned to the new location, so the focal item will pan to the center instead of at the top left corner. This is done with some offset X and Y constants.



