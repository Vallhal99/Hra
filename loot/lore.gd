class_name Lore
extends RefCounted
## Příběh dema "Poslední pečeť": postavy a epilogy.

const CHARS := [
	{"name": "Hrdina (Poutník)", "role": "Námezdní bojovník, 27 let",
	 "char": "Mlčenlivý, věrný, s jizvami na těle i na duši. Slovo dodrží, i když ho to stojí.",
	 "life": "Narodil se v pohraniční vsi, kterou vypálili. Od patnácti žije od zakázky k zakázce a nikde dlouho nezůstává.",
	 "goal": "Najít místo, kam patří.", "fate": "Je na tobě, jestli zůstane, nebo půjde dál."},
	{"name": "Lia", "role": "Prodavačka a léčitelka, 22 let",
	 "char": "Mírná, ale s ostrým jazykem. Ráda dokazuje, že víc než tím, co prodává, je tím, co dokáže.",
	 "life": "Vyrostla v obchodě po matce, která ji naučila rozeznat léčivou bylinu od jedovaté. Vesnici nikdy neopustila.",
	 "goal": "Dokázat, že se nemusí bát světa za hranicí vsi.", "fate": "Z její lékárničky se stane nejlepší léčivý obchod v kraji."},
	{"name": "Rys", "role": "Bývalý zbojník, 30 let",
	 "char": "Cynik se zlatým srdcem (dobře schovaným). Vtipkuje, když je mu nejhůř.",
	 "life": "Sirotek z hvozdu. Zbojníci ho vzali pod křídla, protože neměl kam jít. Když jeho parta rozbila pečeť, pochopil, že to přehnali.",
	 "goal": "Napravit, co jeho parta způsobila.", "fate": "Dostane od vesnice odpuštění i místo hlídače u hřbitova."},
	{"name": "Brum", "role": "Kovář, 48 let",
	 "char": "Mlčenlivý obr. Mluví hlavně kladivem. Vyslovené slovo bere vážně.",
	 "life": "Před dvaceti lety s mnichy kul pečeť Gorvanovy hrobky a od té doby se bál, že jednou praskne.",
	 "goal": "Dokončit, co začal. Ochránit to, co vyrobil.", "fate": "Otevře největší kovárnu široko daleko a naučí učně vlastní kladivo."},
	{"name": "Farář Alois", "role": "Farář na hřbitově, 63 let",
	 "char": "Laskavý, ustaraný, tvrdohlavý. Víc se bojí o druhé než o sebe.",
	 "life": "Čtyřicet let nosil klíč od mauzolea na krku. Slíbil mnichům, že hrobku bude hlídat až do smrti.",
	 "goal": "Udržet mrtvé v klidu a živé v bezpečí.", "fate": "Konečně se vyspí."},
	{"name": "Hostinský Bohouš", "role": "Hostinský U Zlatého sudu, 55 let",
	 "char": "Hovorný, dobrosrdečný, všechno ví. Kdo zná jeho historky, ten se nenudí.",
	 "life": "Hostinec zdědil po otci a ten po svém otci. Každému hostu nalije, i když nemá, čím platit.",
	 "goal": "Aby se k němu každý rád vracel.", "fate": "Hostinec mu praská ve švech od nových hostů."},
	{"name": "Rybář Tomáš", "role": "Rybář, 41 let",
	 "char": "Trpělivý, líný a filozofický. Věří, že každý problém vyřeší ráno u vody.",
	 "life": "Rybaří u Jezera od dětství. Jeskyně se mu vždycky zdála divná, ale nikdy tam nešel.",
	 "goal": "Chytit tu největší rybu, o které vypráví už dvacet let.", "fate": "Konečně ji chytí. Nikdo mu to nevěří."},
	{"name": "Zběhlý hlídač", "role": "Bývalý strážný, 38 let",
	 "char": "Opatrný, tichý, vždycky nad věcí. Raději varuje, než bojuje.",
	 "life": "Hlídal vesnici, dokud zbojníci neodvedli jeho přítele. Pak odešel a skrývá se u tábora.",
	 "goal": "Kraj bez zbojníků, aby se mohl vrátit domů.", "fate": "Vrátí se do vsi a znovu přijme službu."},
	{"name": "Kostěný král Gorvan", "role": "Dávný král, zapečetěný před 100 lety",
	 "char": "Pyšný a nelítostný. I po smrti trvá na tom, že mu vše patří.",
	 "life": "Vládl krajem železnou rukou a po smrti ho mniši zapečetili, protože by jinak povstal. Zbojníci pečeť rozbili.",
	 "goal": "Vrátit se na trůn.", "fate": "Po porážce konečně spí."},
]

const ENDING := {
	"zustat": {
		"title": "Domov",
		"text": "Vesnice U Zlatého sudu otevřela hrdinovi dveře napořád. Pečeť pod mauzoleem drží a Gorvan spí. Kovárna zvoní od rána, v hostinci se zpívá a z hřbitova už se neozývá chrastění.",
		"party": ["Lia: Otevřela vlastní obchod a jmenuje se Lékárna U Poutníka.", "Rys: Hlídá hřbitov a pokaždé, když projde kolem hrobky, smekne klobouk.", "Brum: Vyučil prvního učně a poprvé po dvaceti letech se pořádně vyspal."]},
	"putovat": {
		"title": "Dál po cestě",
		"text": "Hrdina odešel ze vsi za svítání, v batohu chleba od Bohouše a v srdci pocit, že tentokrát odchází jako ten, kdo něco změnil. Cesta je dlouhá, ale dveře U Zlatého sudu mu zůstanou otevřené.",
		"party": ["Lia: Jde s tebou a po cestě sbírá léčivé byliny do nové knihy.", "Rys: Slíbil, že už nikdy nic nevykopá, a o půl dne později už zase vtipkuje.", "Brum: Vezme kladivo a prohlásí, že kovat se dá všude."]},
}


static func ending_text(kind: String) -> String:
	var e: Dictionary = ENDING.get(kind, ENDING.zustat)
	var t := "[center][font_size=34][b]%s[/b][/font_size][/center]\n\n%s\n\n" % [e.title, e.text]
	for l in e.party:
		t += "• " + l + "\n"
	t += "\n[center][i]Konec dema \"Poslední pečeť\". Můžeš pokračovat ve hře a prozkoumat zbytek světa.[/i][/center]"
	return t
