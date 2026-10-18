from pathlib import Path
import hashlib,json,re
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;P=E/'candidate'
catalog=json.loads((R/'assets/localization/catalog.json').read_text(encoding='utf-8'))
rows=[
(' · 推第%d车（%d担）出冈',' · 推第%d車（%d擔）出岡',' · Push cart %d (%d loads) out',' · 第%d車（%d担）を岡外へ押す'),
('%s · 第%d车（%d担）%s','%s · 第%d車（%d擔）%s','%s · Cart %d (%d loads): %s','%s · 第%d車（%d担）%s'),
('七星与白胜巧施酒计，十五名押送者麻倒，七车十一担已运出黄泥冈。','七星與白勝巧施酒計，十五名押送者麻倒，七車十一擔已運出黃泥岡。','The Seven Stars and Bai Sheng carried out the wine ruse. All fifteen escorts were drugged, and seven carts carrying eleven loads left Huangnigang.','七星と白勝の酒計で十五人の護送者が倒れ、十一担を載せた七台の車が黄泥岡を出た。'),
('七星全部倒下，无人能够推出剩余江州车。','七星全部倒下，無人能夠推出剩餘江州車。','All Seven Stars have fallen. Nobody can push out the remaining Jiangzhou carts.','七星が全員倒れ、残りの江州車を押し出せる者がいない。'),
('七星各领一辆江州车。按车旁标记弃枣、装入指定财物，再右键西口标记推车出冈；白胜同行。车上载担数已标明，合计十一担。','七星各領一輛江州車。按車旁標記棄棗、裝入指定財物，再右鍵西口標記推車出岡；白勝同行。車上載擔數已標明，合計十一擔。','Each of the Seven Stars handles one Jiangzhou cart. Use its marker to discard the dates and load the assigned gifts, then right-click the western marker to push it out. Bai Sheng accompanies them. Each cart shows its share of the eleven loads.','七星が一人一台の江州車を受け持つ。標識でナツメを捨てて指定の財宝を積み、西口の標識を右クリックして車を押し出す。白勝も同行する。各車の積載数は表示され、合計十一担となる。'),
('七星和枣车早已在松阴歇脚，押队会从东路陆续上冈。等他们停担歇凉，杨志再来盘问；白胜在盘问后自行挑酒入松阴，停稳后落担。人物始终可选可控，也能随时动武强夺。后续酒计、弃枣装车与七车十一担的撤出仍由你分人配合。','七星和棗車早已在松陰歇腳，押隊會從東路陸續上岡。等他們停擔歇涼，楊志再來盤問；白勝在盤問後自行挑酒入松陰，停穩後落擔。人物始終可選可控，也能隨時動武強奪。後續酒計、棄棗裝車與七車十一擔的撤出仍由你分人配合。','The Seven Stars and their date carts are already resting in the pine shade. The escort climbs from the east; Yang Zhi questions the merchants after the party rests. Bai Sheng then brings in and sets down the wine. Characters remain under your control, and fighting switches to the force route. You direct the wine ruse, the loading of seven carts, and the removal of all eleven loads.','七星とナツメの車はすでに松陰で休んでいる。護送隊は東から順に登り、休息後に楊志が商人を尋問する。その後、白勝が酒を運び込み、停止して下ろす。人物は常に操作でき、戦えば強奪ルートへ移る。酒計、ナツメの投棄、七台への積み込みと十一担の搬出は自ら指揮する。'),
('七星推七辆江州车带走十一担财物，与白胜一同全身出冈。','七星推七輛江州車帶走十一擔財物，與白勝一同全身出岡。','The Seven Stars pushed eleven loads out in seven Jiangzhou carts and escaped safely with Bai Sheng.','七星が七台の江州車に十一担を載せ、白勝とともに無事に岡を出た。'),
('七车十一担已到 · 收拢同行人','七車十一擔已到 · 收攏同行人','Seven carts, eleven loads delivered · Regroup','七台・十一担が到着 · 仲間を集める'),
('七辆江州车已推出冈口。让七星与白胜一起到西口，可完成全员生还目标；先行收队仍需你实际下令。','七輛江州車已推出岡口。讓七星與白勝一起到西口，可完成全員生還目標；先行收隊仍需你實際下令。','All seven Jiangzhou carts are outside. Bring the Seven Stars and Bai Sheng to the western exit for the all-safe objective. Leaving early still requires your order.','江州車七台は岡口の外へ出た。七星と白勝を西口に集めれば全員生還となる。先に撤収する場合も自ら命令する必要がある。'),
('七辆江州车载十一担生辰纲出冈。','七輛江州車載十一擔生辰綱出岡。','Seven Jiangzhou carts carried all eleven tribute loads out.','十一担の生辰綱を載せた七台の江州車が岡を出た。'),
('倒下，第%d车（%d担）留在原地，可由幸存七星接力。','倒下，第%d車（%d擔）留在原地，可由倖存七星接力。',' fell. Cart %d (%d loads) remains here for a surviving Star to take over.','が倒れた。第%d車（%d担）はその場に残り、生き残った七星が引き継げる。'),
('倒下；幸存七星仍可接力推车。','倒下；倖存七星仍可接力推車。',' fell; surviving Stars can still take over the carts.','が倒れた。生き残った七星は引き続き車を引き継げる。'),
('先让他们看过好酒。刘唐争酒引目，我与白胜在桶旁配合；药入酒桶之后，弃枣装车，遮盖了推走，莫再生枝节。','先讓他們看過好酒。劉唐爭酒引目，我與白勝在桶旁配合；藥入酒桶之後，棄棗裝車，遮蓋了推走，莫再生枝節。','Let them see the good wine first. Liu Tang draws their eyes while Bai Sheng and I work by the bucket. Once the drug is in, discard the dates, load and cover the carts, and push them away without further trouble.','まず良い酒だと見せる。劉唐が酒をねだって目を引き、私と白勝が桶のそばで合わせる。薬が入ったらナツメを捨て、財宝を積んで覆い、余計な騒ぎを起こさず押し去ろう。'),
('六月黄泥冈，七星已扮作贩枣客，在另一片松阴散坐。东路上，杨志催着十一名军汉挑担，两个虞候和老都管还跟在后头。白胜此时尚未来卖酒。十一担财物保留各自编号，七星将弃枣后用原来的七辆江州车装运。','六月黃泥岡，七星已扮作販棗客，在另一片松陰散坐。東路上，楊志催著十一名軍漢挑擔，兩個虞候和老都管還跟在後頭。白勝此時尚未來賣酒。十一擔財物保留各自編號，七星將棄棗後用原來的七輛江州車裝運。','At Huangnigang in the sixth month, the Seven Stars sit in pine shade disguised as date merchants. Yang Zhi urges eleven load bearers uphill from the east, followed by two attendants and the old steward. Bai Sheng has not arrived with wine. All eleven loads retain distinct identities; after discarding the dates, the Seven Stars will use their original seven Jiangzhou carts.','六月の黄泥岡。七星はナツメ商人に扮し、別の松陰で休んでいる。東では楊志が十一人の軍漢を急がせ、二人の虞候と老都管が続く。白勝はまだ酒を売りに来ていない。十一担はそれぞれの番号を保ち、七星はナツメを捨てた後、元の七台の江州車に積む。'),
('只选中未推车的同伴；按车旁七星姓名分别下令。','只選中未推車的同伴；按車旁七星姓名分別下令。','Select companions not pushing a cart; follow the Star named on each marker.','車を押していない仲間を選び、標識にある七星の名前に従って個別に命令する。'),
('商客歇脚','商客歇腳','Merchants resting','商人が休息中'),
('好汉击退押队，七车十一担已运出黄泥冈。','好漢擊退押隊，七車十一擔已運出黃泥岡。','The heroes repelled the escort and took seven carts carrying eleven loads out of Huangnigang.','好漢たちは護送隊を退け、七台に載せた十一担を黄泥岡から運び出した。'),
('将十一担生辰纲装入七辆江州车，推车出冈并收拢同行好汉。','將十一擔生辰綱裝入七輛江州車，推車出岡並收攏同行好漢。','Pack all eleven tribute loads into seven Jiangzhou carts, push them out, and regroup with your companions.','十一担の生辰綱を七台の江州車に積み、岡の外へ押し出して同行者を集める。'),
('弃枣装车 · 七车装十一担','棄棗裝車 · 七車裝十一擔','Discard dates · Eleven loads into seven carts','ナツメを捨てる · 七台に十一担を積む'),
('押送队已经拒酒并迎战。七星按车旁标记将十一担财物装入七辆江州车。原负责者倒下时，幸存七星可接力推车；白胜仍为同行卖酒人。','押送隊已經拒酒並迎戰。七星按車旁標記將十一擔財物裝入七輛江州車。原負責者倒下時，倖存七星可接力推車；白勝仍為同行賣酒人。','The escort has refused the wine and is fighting. The Seven Stars can use the markers to pack eleven loads into seven Jiangzhou carts. If a cart handler falls, a surviving Star can take over. Bai Sheng remains the accompanying wine seller.','護送隊は酒を拒み、戦い始めた。七星は標識に従って十一担を七台の江州車に積む。担当者が倒れた場合は、生き残った七星が車を引き継げる。白勝は同行する酒売りの役を保つ。'),
('接手','接手','Take over','引き継ぐ'),
('推起第%d车，载%d担财物。','推起第%d車，載%d擔財物。',' started pushing cart %d with %d tribute loads.','が第%d車を押し始めた。財宝%d担を積んでいる。'),
('收拢同行人','收攏同行人','Regroup companions','同行者を集める'),
('智取生辰纲 | %s | 推车%d/7 · 财物%d/11担','智取生辰綱 | %s | 推車%d/7 · 財物%d/11擔','Birthday Gifts | %s | Carts %d/7 · Loads %d/11','生辰綱の智取 | %s | 車%d/7 · 財宝%d/11担'),
('江州车·第%d车（%d担）','江州車·第%d車（%d擔）','Jiangzhou cart %d (%d loads)','江州車・第%d車（%d担）'),
('生辰纲·第%d担','生辰綱·第%d擔','Birthday tribute · Load %d','生辰綱・第%d担'),
('白胜卖酒','白勝賣酒','Bai Sheng sells wine','白勝が酒を売る'),
('白胜挑酒入场','白勝挑酒入場','Bai Sheng brings the wine','白勝が酒を運び込む'),
('第%d车弃枣，装入%d担财物并遮盖。','第%d車棄棗，裝入%d擔財物並遮蓋。','Cart %d: dates discarded; %d tribute loads packed and covered.','第%d車のナツメを捨て、財宝%d担を積んで覆った。'),
('第%d车由%s推出黄泥冈，共载%d担。','第%d車由%s推出黃泥岡，共載%d擔。','Cart %d was pushed out of Huangnigang by %s, carrying %d loads.','第%d車を%sが黄泥岡の外へ押し出した。積荷は%d担。'),
('装车','裝車','Load','積み込む'),
('装车推行','裝車推行','Load and push carts','積み込んで車を押す'),
('请由此车的七星同伴接手；一人不能同时推两辆车。','請由此車的七星同伴接手；一人不能同時推兩輛車。','Use the Star assigned to this cart. One person cannot push two carts at once.','この車の担当である七星に引き継がせる。一人で二台を同時に押すことはできない。'),
('身份败露','身分敗露','Disguise exposed','正体が露見'),
]
added={}
for key,tw,en,ja in rows:
 expected=re.findall(r'%(?:\d+\$)?[sd]',key)
 for value in [tw,en,ja]:assert re.findall(r'%(?:\d+\$)?[sd]',value)==expected,key
 added[key]={'zh_TW':tw,'en':en,'ja':ja}
for i in range(7):
 weight=2 if i<4 else 1;key='江州车·第%d车（%d担）'%(i+1,weight)
 added[key]={'zh_TW':'江州車·第%d車（%d擔）'%(i+1,weight),'en':'Jiangzhou cart %d (%d loads)'%(i+1,weight),'ja':'江州車・第%d車（%d担）'%(i+1,weight)}
for i in range(11):
 key='生辰纲·第%d担'%(i+1);added[key]={'zh_TW':'生辰綱·第%d擔'%(i+1),'en':'Birthday tribute · Load %d'%(i+1),'ja':'生辰綱・第%d担'%(i+1)}
catalog.update(added)
name='assets/localization/catalog.json';target=P/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
spec=json.loads((E/'integration_candidate.json').read_text());assert all(x['path']!=name for x in spec['files']);spec['files'].append({'path':name,'before_sha256':sha(R/name),'candidate_sha256':sha(target)});(E/'integration_candidate.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(E/'localization_additions.json').write_text(json.dumps({'new_or_updated':added,'count':len(added),'old_entries_unchanged':all(catalog[k]==v for k,v in json.loads((R/name).read_text(encoding='utf-8')).items() if k not in added),'format_placeholder_order_checked':True,'actual_ui_checked':False},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'candidate_catalog_entries':len(catalog),'added_or_updated':len(added),'placeholder_check':True,'actual_ui_checked':False}))
