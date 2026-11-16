# -*- coding: utf-8 -*-
# Příběh dema "Poslední pečeť" – přepisuje/doplňuje dialogy, úkoly a předměty z gen.py
def N(id,sp,text,choices=None,effects=None,nxt=None):
    n={'id':id,'speaker':sp,'text':text}
    if choices: n['choices']=choices
    if effects: n['effects']=effects
    if nxt: n['next']=nxt
    return n
def C(text,nxt,cond=None,effects=None):
    c={'text':text,'next':nxt}
    if cond: c['cond']=cond
    if effects: c['effects']=effects
    return c
def put_dialogue(d):
    D['dialogues']=[x for x in D['dialogues'] if x['id']!=d['id']]+[d]

# ---------- předměty ----------
D['items'].append({'id':'klic_mauzolea','name':'Klíč od mauzolea','category':'Ostatní','slot':'','atk':0,'def':0,'hp':0,'sp':0,'use':{},'price':0,'desc':'Starý železný klíč. Farář Alois ho střežil čtyřicet let.'})
D['items'].append({'id':'pecetni_hrot','name':'Pečetní hrot','category':'Zbraně/Kopí','slot':'zbran','atk':16,'def':0,'hp':0,'sp':0,'use':{},'price':0,'desc':'Hrot kopí z kovářovy nejlepší oceli a kostního prachu. Mrtví před ním ustupují.','icon':'items/kopi.png'})

# ---------- úkoly ----------
Q=D['quests']
for q in Q:
    if q['id']=='kral':
        q['desc']='Pečeť je obnovená. Sestup do Hrobky pod mauzoleem a poraz Kostěného krále Gorvana.'
        q['level']=4
    if q['id']=='tabor':
        q['desc']='Zbojníci v Hvozdu přepadají cestovatele a prý v noci kopali na hřbitově. Poraz čtyři z nich.'
Q.append({'id':'neklid','name':'Neklidné hroby','giver':'Farář Alois','desc':'Na hřbitově se zjevují přízraky. Poraz dva, ať farář zjistí, odkud se berou.','level':3,
 'objectives':[{'type':'event','target':'kill:Přízrak','count':2,'text':'Poraz přízraky na hřbitově (2)'}],
 'rewards':{'xp':250,'gold':100,'items':[['klic_mauzolea',1],['lektvar',2]]}})
Q.append({'id':'zapecetit','name':'Pečeť z oceli','giver':'Kovář Brum','desc':'Kovář Brum před dvaceti lety kul pečeť Gorvanovy hrobky. Obnovit ji může jen s rudou a kostním prachem.','level':3,
 'objectives':[{'type':'collect','target':'ruda','count':3,'take':True,'text':'Přines Železnou rudu (3)'},{'type':'collect','target':'kost','count':2,'take':True,'text':'Přines Kostní prach (2)'}],
 'rewards':{'xp':300,'gold':0,'items':[['pecetni_hrot',1]]}})

# ---------- dialogy ----------
put_dialogue({'id':'prolog','name':'Prolog','start':'p1','nodes':[
 N('p1','Vypravěč','Pět let jsi putoval od vsi ke vsi jako námezdní bojovník. Žádný domov, žádný cíl, jen cesta a v kapse pár mincí.'),
 ] and [N('p1','Vypravěč','Pět let jsi putoval od vsi ke vsi jako námezdní bojovník. Žádný domov, žádný cíl, jen cesta a v kapse pár mincí.',nxt='p2'),
 N('p2','Vypravěč','Dnes jsi dorazil na Rozcestí. Na jihu leží vesnice U Zlatého sudu a lidé říkají, že tam hledají odvážné ruce. Řeka, hvozd i hřbitov jsou prý poslední dobou neklidné.',nxt='p3'),
 N('p3','Vypravěč','Tip: pohyb WASD/šipky nebo páka, E = mluvit, J = deník úkolů, Esc = menu (družina, vaření, bestiář).')]})

put_dialogue({'id':'hlidka','name':'Hlídač','start':'h1','nodes':[
 N('h1','Zběhlý hlídač','Pst! Tábor zbojníků je na jihovýchodě. Kdyby je někdo zahnal, kraj by si oddechl.',[
   C('Zahnat je? Beru to.','h_ok',{'quest_not_started':'tabor'}),
   C('Tábor je hotový.','h_done',{'quest_ready':'tabor'}),
   C('Rozloučit se.','h_bye')]),
 N('h_ok','Zběhlý hlídač','Hlídej si záda. Můžeš je překvapit zezadu, nebo jim nastražit past (klávesa T). A slyšel jsem, že v noci kopali na starém hřbitově. Proč, to nevím.',effects=[{'start_quest':'tabor'}]),
 N('h_done','Zběhlý hlídač','Báječně! Jeden z nich, Rys, na tebe už čeká za rohem. Prý ti chce něco říct.',effects=[{'complete_quest':'tabor'},{'recruit':'rys'}],nxt='h_rys'),
 N('h_rys','Rys','Takže ty jsi ten, co rozprášil naši partu. Dobře, že to byl někdo, kdo neřeže hned. Poslouchej: byl jsem u toho, když jsme kopali pod mauzoleem. Hledali jsme královský poklad.',nxt='h_rys2'),
 N('h_rys2','Rys','Pod deskou byla pečeť. Šéf ji rozbil kladivem. Pak se ozvalo to... chrastění. Utekl jsem první. Teď to musím napravit. Beru tě za slovo, jdu s tebou.',effects=[{'set_flag':'rys_vina'}]),
 N('h_bye','Zběhlý hlídač','Opatrně, cizinče.')]})

put_dialogue({'id':'knez','name':'Farář – rozhovor','start':'f1','nodes':[
 N('f1','Farář Alois','Pokoj s tebou, poutníku. Ale ne s tímhle místem... Hřbitov už není, co býval.',[
   C('Co se tu děje?','f_n',{'quest_not_started':'neklid'}),
   C('Přízraky jsou pryč.','f_n_done',{'quest_ready':'neklid'}),
   C('Kde je ten přízrak, o kterém mluvíš?','f_n_where',{'quest_active':'neklid'}),
   C('Brum už pečeť obnovil.','f_seal',{'quest_done':'zapecetit','quest_not_started':'kral'}),
   C('Co mám dělat dál?','f_next',{'quest_done':'neklid','quest_not_started':'zapecetit'}),
   C('Kde je ta Hrobka?','f_where',{'quest_active':'kral'}),
   C('Kostěný král je poražen.','f_end',{'quest_ready':'kral'}),
   C('Jak se ti daří, otče?','f_after',{'quest_done':'kral'}),
   C('Nashledanou.','f_bye')]),
 N('f_n','Farář Alois','Před sto lety tu byl pohřben král Gorvan, krutý panovník. Mniši ho zapečetili pod mauzoleem. Teď se ze země zjevují přízraky. Poraz dva z nich, ať vidím, jak silně je pečeť poškozená. Jsou slabí proti světlu a ohni.',[C('Postarám se o to.','f_n_ok',effects=[{'start_quest':'neklid'}]),C('Nejdřív se připravím.','f1')]),
 N('f_n_ok','Farář Alois','Ať tě světlo provází.'),
 N('f_n_where','Farář Alois','Potulují se po hřbitově. Hledej jejich modrou záři.'),
 N('f_n_done','Farář Alois','Dobrá práce. Pečeť je tedy opravdu rozbitá, jak jsem se bál. Tady je klíč od mauzolea. Čtyřicet let jsem ho nosil na krku a doufal, že ho nikdy nebudu potřebovat.',effects=[{'complete_quest':'neklid'}],nxt='f_next'),
 N('f_next','Farář Alois','Pečeť před dvaceti lety opravoval kovář Brum. Jen on ví, jak ji znovu ukovat. Zajdi za ním do vesnice. Řekni mu, že tě posílám já.'),
 N('f_seal','Farář Alois','Díky Bohu. Pečeť drží, ale král už je vzhůru a uvnitř jeho kostlivců přibývá. Musíš sestoupit do Hrobky a skoncovat s ním. Dveře jsou v mauzoleu na severu hřbitova.',[C('Jdu na to.','f_ok',effects=[{'start_quest':'kral'}]),C('Ještě se připravím.','f1')]),
 N('f_ok','Farář Alois','Vezmi si lektvary a nech si u kováře vylepšit zbraň. Kostěný král je slabý proti světlu, ohni a sekeře. Ať tě světlo provází.'),
 N('f_where','Farář Alois','Mauzoleum na severu hřbitova. Uvnitř jdi stále na sever, král sedí na pódiu.'),
 N('f_end','Farář Alois','Takže je po všem? Slyšel jsem, jak se zem otřásla... Děkuji ti, hrdino. Všechny mrtvé jsi vrátil k odpočinku. Co teď uděláš?',[
   C('Zůstanu tady. Tohle místo je teď můj domov.','f_stay'),
   C('Půjdu dál. Cesta na mě ještě čeká.','f_go')]),
 N('f_stay','Farář Alois','Vesnice ti otevře dveře i srdce. Tohle je odměna od všech vesničanů.',effects=[{'complete_quest':'kral'},{'set_flag':'konec_zustat'},{'ending':'zustat'}]),
 N('f_go','Farář Alois','Cesta tě volá a ty ji nikdy nezradíš. Tohle je odměna od všech vesničanů. Vždy se můžeš vrátit.',effects=[{'complete_quest':'kral'},{'set_flag':'konec_putovat'},{'ending':'putovat'}]),
 N('f_after','Farář Alois','Hřbitov je klidný jako nikdy. Děkuji ti.'),
 N('f_bye','Farář Alois','Pokoj s tebou.')]})

put_dialogue({'id':'kovar','name':'Kovář – rozhovor','start':'k1','nodes':[
 N('k1','Kovář Brum','Hmpf. Potřebuješ pořádnou ocel, nebo jen okukuješ moje kovadlinu?',[
   C('Ukaž mi zbraně a zbroj.','k_shop'),
   C('Potřebuji opravit výbavu nebo vylepšit zbraň.','k_rep'),
   C('Farář Alois mě posílá kvůli pečeti.','k_p1',{'quest_done':'neklid','quest_not_started':'zapecetit'}),
   C('Mám rudu a kostní prach.','k_p2',{'quest_ready':'zapecetit'}),
   C('Co ta pečeť? Potřebuješ ještě něco?','k_p1w',{'quest_active':'zapecetit'}),
   C('Jen jdu okolo.','k_bye')]),
 N('k_rep','Kovář Brum','Dej to sem. Spočítám ti to podle škod.',effects=[{'shop':'kovar'}],nxt='k1'),
 N('k_shop','Kovář Brum','Tohle je poctivá práce. Vyber si.',effects=[{'shop':'kovar'}],nxt='k1'),
 N('k_p1','Kovář Brum','Hmpf. Takže se to stalo. Před dvaceti lety jsem ji kul já, s mnichy. Pečeť z oceli, zalitá kostním prachem. Pamatuju si ji do poslední rýhy.',nxt='k_p1b'),
 N('k_p1b','Kovář Brum','Potřebuju tři kusy železné rudy a dvě hrsti kostního prachu. Ruda i prach padají z kostlivců a zbojníků. Obchoduju s nimi taky, ale bez prachu to nepůjde. Přines mi to.',[C('Mám to u sebe. Hned se vrátím.','k_p1c',effects=[{'start_quest':'zapecetit'}]),C('Vrátím se.','k1')]),
 N('k_p1c','Kovář Brum','Hmpf. Dobře.'),
 N('k_p1w','Kovář Brum','Tři kusy rudy, dvě hrsti prachu. Jinak ti nic neukovám.'),
 N('k_p2','Kovář Brum','Hmpf. To stačí. Kladivo sem. ...Hotovo. Pečeť je zpátky na místě. Tady, z odřezků jsem ti ukul hrot kopí. Mrtví před ním ustupují. A ještě něco: půjdu s tebou. Je to moje pečeť, moje práce.',effects=[{'complete_quest':'zapecetit'},{'recruit':'brum'},{'set_flag':'seal_done'}]),
 N('k_bye','Kovář Brum','Tak ať ti meč slouží.')]})

put_dialogue({'id':'hostinsky','name':'Hostinský – rozhovor','start':'h1','nodes':[
 N('h1','Hostinský Bohouš','Vítej v hostinci U Zlatého sudu! Postel za 20 zlatých a ráno ti dám i snídani.',[
   C('Přenocovat (20 zl., uložit hru).','h_rest',{'gold_min':20}),
   C('Co je nového?','h_news'),
   C('Povídej o vsi.','h_lore'),
   C('Jen se dívám.','h_bye')]),
 N('h_rest','Hostinský Bohouš','Zzzz... Dobré ráno! Hra byla uložena do slotu 1. Máš naspáno?',effects=[{'rest':20}]),
 N('h_news','Hostinský Bohouš','Povídá se, že na hřbitově straší a v Hvozdu řádí zbojníci. Farář Alois je z toho celý bez sebe, nikdy ho neviděl nespat. A kovář prý umí vylepšit i obyčejný meč.'),
 N('h_lore','Hostinský Bohouš','Vesnici založil můj pradědeček, když jsme tu našli pramen a zlatý sud pod kořeny dubu. Dub už je dávno pryč, hospoda zůstala. Lidé se k nám vždycky vrátí. I ti, co odešli.'),
 N('h_bye','Hostinský Bohouš','Kdyby něco, jen zavolej.')]})
