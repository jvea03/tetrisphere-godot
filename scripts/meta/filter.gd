class_name TSFilter
extends RefCounted

## Keeps crude language out of what players type for others to see: club
## chat and the Leader's message are starred ("****"), and names are
## refused outright (is_clean) -- a starred name on a leaderboard reads
## worse than being asked for another.
##
## Words are compared after undoing the usual dodges: case, look-alike
## digits and symbols (sh1t, $hit, @ss), stretched letters (fuuuck) and
## spaced-out letters (f u c k). Two lists keep innocent words safe:
##   ROOTS -- caught anywhere inside a word (fucking, bullshit); only
##            stems no clean English word contains go here
##   WORDS -- caught only as the whole word, since they hide inside clean
##            ones (ass in class, cock in peacock, tit in title)
## This runs on the device, which is all the simulated clubs need. A real
## chat server would filter on its side too.

const ROOTS := [
	"fuck", "fuk", "fck", "shit", "cunt", "bitch", "biatch", "whore", "slut",
	"nigger", "nigga", "fagg", "faggot", "retard", "motherf", "dickhead",
	"asshole", "arsehole", "jackass", "dumbass", "bullshit", "wanker",
	"twat", "bollock", "pussies", "cocksuck", "blowjob", "handjob", "kike",
	"tranny", "dildo", "porn", "penis", "vagina",
]

const WORDS := [
	"ass", "asses", "arse", "bastard", "bastards", "dick", "dicks", "cock",
	"cocks", "pussy", "piss", "pissed", "tit", "tits", "titties", "boob",
	"boobs", "fag", "fags", "hoe", "hoes", "rape", "rapist", "rapists", "sex",
	"sexy", "nazi", "wtf", "stfu", "milf", "spic", "spics", "chink", "chinks", "cum", "jizz", "prick",
	"douche", "skank", "thot", "negro", "coon", "gook", "wetback",
]

## Clean words a stem above happens to sit inside: taken out of a word
## before the stems are looked for, so "Scunthorpe" and "therapist" pass.
const ALLOW := [
	"scunthorpe", "shiitake", "shitake", "fukushima", "retardant", "therapist",
	"penistone", "cocktail", "peacock", "hancock", "dickens", "cockpit",
]

const LEET := {
	"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b",
	"@": "a", "$": "s", "!": "i", "|": "i", "+": "t",
	"*": "*", # a star standing in for a letter: see _is_bad
}


## The text with every offending word replaced by asterisks of its length.
static func clean(text: String) -> String:
	var spans := _bad_spans(text)
	if spans.is_empty():
		return text
	var chars := text.split("")
	for span in spans:
		for i in range(span.x, span.y):
			if chars[i] != " ":
				chars[i] = "*"
	return "".join(chars)


static func is_clean(text: String) -> bool:
	return _bad_spans(text).is_empty()


## [start, end) character ranges of the words to hide.
static func _bad_spans(text: String) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	var tokens := _tokens(text)
	var i := 0
	while i < tokens.size():
		var t: Dictionary = tokens[i]
		if _is_bad(t["word"]):
			spans.append(Vector2i(t["start"], t["end"]))
			i += 1
			continue
		# spaced-out letters: "f u c k" -- a run of one-letter tokens
		if t["word"].length() == 1:
			var j := i
			var joined := ""
			while j < tokens.size() and tokens[j]["word"].length() == 1:
				joined += tokens[j]["word"]
				j += 1
			if j - i >= 3 and _contains_root(joined):
				spans.append(Vector2i(t["start"], tokens[j - 1]["end"]))
				i = j
				continue
		i += 1
	return spans


## Words with their positions; look-alike symbols count as letters here,
## so "$h!t" is one word, not three.
static func _tokens(text: String) -> Array:
	var out := []
	var start := -1
	var word := ""
	for k in text.length() + 1:
		var ch := text[k].to_lower() if k < text.length() else " "
		var letter := (ch >= "a" and ch <= "z") or LEET.has(ch)
		if letter:
			if start < 0:
				start = k
				word = ""
			word += LEET.get(ch, ch)
		elif start >= 0:
			out.append({"word": word, "start": start, "end": k})
			start = -1
	return out


static func _is_bad(word: String) -> bool:
	# "f*ck", "sh*t": each star tried as a vowel (up to two stars). A word of
	# only stars is already hidden.
	if word.contains("*"):
		if word.replace("*", "") == "" or word.count("*") > 2:
			return false
		for v in ["a", "e", "i", "o", "u"]:
			var once := _replace_first(word, "*", v)
			if _is_bad(once):
				return true
		return false
	if WORDS.has(word) or WORDS.has(_squeeze(word, 2)):
		return true
	for ok in ALLOW:
		word = word.replace(ok, "")
	return word != "" and _contains_root(word)


static func _contains_root(word: String) -> bool:
	var squeezed := _squeeze(word)
	for root in ROOTS:
		if word.contains(root) or squeezed.contains(_squeeze(root)):
			return true
	return false


## Runs of one letter cut to at most `keep`: "fuuuuck" -> "fuck". Roots are
## squeezed the same way before comparing, so "faggot" still matches as
## "fagot". Whole words keep doubles (keep 2): "asss" -> "ass", where
## squeezing to one letter would leave "as", a clean word.
static func _squeeze(word: String, keep: int = 1) -> String:
	var out := ""
	var run := 0
	for ch in word:
		if out != "" and out[out.length() - 1] == ch:
			run += 1
		else:
			run = 1
		if run <= keep:
			out += ch
	return out


static func _replace_first(s: String, what: String, with: String) -> String:
	var i := s.find(what)
	return s if i < 0 else s.substr(0, i) + with + s.substr(i + what.length())
