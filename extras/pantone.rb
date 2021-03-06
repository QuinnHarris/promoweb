module Pantone
  class Color
    cattr_reader :colors
    
    def initialize(list)
      @names = list[0..-2]
      @value = list.last
    end
    
    def full_name
      "PMS #{@names.join(' ')}"
    end
    
    def hex
      "#%06x" % @value
    end
    
    def self.find(name)
      l = @@colors.find { |list| list.first == name }
      return nil unless l
      self.new(l)
    end
    
    @@colors = [
  ['Process Yellow', 0xf7e214], ['Yellow', 0xfff000], ['100', 0xf4ed7c], ['101', 0xf4ed47], ['102', 0xf9e814], ['Industry Yellow', 0xfce016], ['103', 0xc6ad0f], ['104', 0xad9b0c],
  ['105', 0x82750f], ['106', 0xf7e859], ['107', 0xf9e526], ['108', 0xf7dd16], ['109', 'Light Yellow', 0xf9d616], ['110', 0xd8b511], ['111', 0xaa930a],
  ['112', 0x99840a], ['113', 0xf9e55b], ['114', 0xf9e24c], ['115', 0xf9e04c], ['116', 'Medium Yellow', 0xfcd116], ['117', 0xc6a00c], ['118', 0xaa8e0a],
  ['119', 0x897719], ['120', 0xf9e27f], ['121', 0xf9e070], ['122', 0xfcd856], ['123', 'Athletic Gold', 0xffc61e], ['124', 0xe0aa0f], ['125', 0xb58c0a],
  ['1205', 0xf7e8aa], ['1215', 0xf9e08c], ['1225', 0xffcc49], ['1235', 'Dark Yellow', 0xfcb514], ['1245', 0xbf910c], ['1255', 0xa37f14], ['1265', 0x7c6316],
  ['127', 0xf4e287], ['128', 0xf4db60], ['129', 0xf2d13d], ['130', 0xeaaf0f], ['131', 0xc6930a], ['132', 0x9e7c0a], ['133', 0x705b0a],                                                   
  ['134', 0xffd87f], ['135', 0xfcc963], ['136', 0xfcbf49], ['137', 0xfca311], ['138', 0xd88c02], ['139', 0xaf7505], ['140', 0x7a5b11],                                                   
  ['1345', 'Cream', 0xffd691], ['1355', 0xfcce87], ['1365', 0xfcba5e], ['1375', 0xf99b0c], ['1385', 0xcc7a02], ['1395', 0x996007], ['1405', 0x6b4714],
  ['141', 0xf2ce68], ['142', 0xf2bf49], ['143', 0xefb22d], ['144', 0xe28c05], ['145', 'Light Brown', 0xc67f07], ['146', 0x9e6b05], ['147', 0x725e26],
  ['148', 0xffd69b], ['149', 0xfccc93], ['150', 0xfcad56], ['151', 0xf77f00], ['152', 0xdd7500], ['153', 0xbc6d0a], ['154', 0x995905],                                                   
  ['1485', 0xffb777], ['1495', 0xff993f], ['1505', 0xf47c00], ['021', 'Orange', 0xef6b00], ['1525', 0xb55400], ['1535', 0x8c4400], ['1545', 'Brown', 0x4c280f],
  ['155', 0xf4dbaa], ['156', 0xf2c68c], ['157', 0xeda04f], ['158', 0xe87511], ['159', 0xc66005], ['160', 0x9e540a], ['161', 'Brown', 0x633a11],
  ['1555', 0xf9bf9e], ['1565', 0xfca577], ['1575', 0xfc8744], ['1585', 0xf96b07], ['1595', 0xd15b05], ['1605', 0xa04f11], ['1615', 0x843f0f],                                            
  ['162', 0xf9c6aa], ['163', 0xfc9e70], ['164', 0xfc7f3f], ['165', 'Orange', 0xf96302], ['166', 0xdd5900], ['167', 0xbc4f07], ['168', 0x6d3011],
  ['1625', 0xf9a58c], ['1635', 0xf98e6d], ['1645', 0xf97242], ['1655', 0xf95602], ['1665', 0xf95602], ['1675', 0xa53f0f], ['1685', 0x843511],                                            
  ['169', 0xf9baaa], ['170', 0xf98972], ['171', 0xf9603a], ['172', 'Orange', 0xf74902], ['173', 0xd14414], ['174', 0x933311], ['175', 0x6d3321],
  ['176', 0xf9afad], ['177', 0xf9827f], ['178', 0xf95e59], ['WarmRed', 0xf93f26], ['179', 0xe23d28], ['180', 0xc13828], ['181', 0x7c2d23],
  ['1765', 0xf99ea3], ['1775', 0xf9848e], ['1785', 0xfc4f59], ['1788', 0xef2b2d], ['1795', 0xd62828], ['1805', 0xaf2626], ['1815', 0x7c211e],                                            
  ['1767', 0xf9b2b7], ['1777', 0xfc6675], ['1787', 'Light Red', 0xf43f4f], ['032', 'Red', 0xef2b2d], ['1797', 0xcc2d30], ['1807', 0xa03033], ['1817', 0x5b2d28],
  ['182', 0xf9bfc1], ['183', 0xfc8c99], ['184', 0xfc5e72], ['185', 'Red', 0xe8112d], ['186', 'Red', 0xce1126], ['187', 0xaf1e2d], ['188', 0x7c2128],
  ['189', 0xffa3b2], ['190', 'Pink', 0xfc758e], ['191', 0xf4476b], ['192', 0xe5053a], ['193', 'US Flag Red', 0xbf0a30], ['194', 0x992135], ['195', 'Burgundy', 0x772d35],
  ['1895', 0xfcbfc9], ['1905', 0xfc9bb2], ['1915', 0xf4547c], ['1925', 0xe00747], ['1935', 0xc10538], ['1945', 0xa80c35], ['1955', 0x931638],
  ['196', 0xf4c9c9], ['197', 0xef99a3], ['198', 0xe5566d], ['199', 'Fire Red', 0xd81c3f], ['200', 0xc41e3a], ['201', 0xa32638], ['202', 'Maroon', 0x8c2633],

  ['203', 0xf2afc1], ['204', 0xed7a9e], ['205', 'Magenta', 0xe54c7c], ['206', 0xd30547], ['207', 0xaf003d], ['208', 'Burgundy', 0x8e2344], ['209', 'Burgundy', 0x75263d],

  ['210', 'Pink', 0xffa0bf], ['211', 'Pink', 0xff77a8], ['212', 0xf94f8e], ['213', 0xea0f6b], ['214', 0xcc0256], ['215', 0xa50544], ['216', 0x7c1e3f],
  ['217', 0xf4bfd1], ['218', 0xed72aa], ['219', 0xe22882], ['Rubine Red', 0xd10056], ['220', 0xaa004f], ['221', 0x930042], ['222', 'Burgudy', 0x70193d],
  ['223', 0xf993c4], ['224', 0xf46baf], ['225', 'Pink', 0xed2893], ['226', 0xd60270], ['227', 0xad005b], ['228', 0x8c004c], ['229', 0x6d213f],
  ['230', 0xffa0cc], ['231', 0xfc70ba], ['232', 0xf43fa5], ['Rhodamine Red', 0xed0091], ['233', 0xce007c], ['234', 0xaa0066], ['235', 0x8e0554],
  ['236', 0xf9afd3], ['237', 0xf484c4], ['238', 0xed4faf], ['239', 0xe0219e], ['240', 0xc40f89], ['241', 0xad0075], ['242', 0x7c1c51],
  ['2365', 0xf7c4d8], ['2375', 0xea6bbf], ['2385', 0xdb28a5], ['2395', 0xc4008c], ['2405', 0xa8007a], ['2415', 0x9b0070], ['2425', 0x87005b],
  ['243', 0xf2bad8], ['244', 0xeda0d3], ['245', 0xe87fc9], ['246', 0xcc00a0], ['247', 0xb7008e], ['248', 0xa3057f], ['249', 0x7f2860],
  ['250', 0xedc4dd], ['251', 0xe29ed6], ['252', 0xd36bc6], ['Purple', 0xbf30b5], ['253', 0xaf23a5], ['254', 0xa02d96], ['255', 0x772d6b],
  ['256', 0xe5c4d6], ['257', 0xd3a5c9], ['258', 0x9b4f96], ['259', 0x72166b], ['260', 0x681e5b], ['261', 0x5e2154], ['262', 0x542344],
  ['2562', 0xd8a8d8], ['2572', 0xc687d1], ['2582', 0xaa47ba], ['2592', 0x930fa5], ['2602', 0x820c8e], ['2612', 0x701e72], ['2622', 0x602d59],
  ['2563', 0xd1a0cc], ['2573', 0xba7cbc], ['2583', 0x9e4fa5], ['2593', 0x872b93], ['2603', 0x70147a], ['2613', 0x66116d], ['2623', 0x5b195e],
  ['2567', 0xbf93cc], ['2577', 0xaa72bf], ['2587', 'Purple', 0x8e47ad], ['2597', 'Purple', 0x66008c], ['2607', 0x5b027a], ['2617', 0x560c70], ['2627', 0x4c145e],
  ['263', 0xe0cee0], ['264', 0xc6aadb], ['265', 0x9663c4], ['266', 'Purple', 0x6d28aa], ['267', 'Purple', 0x59118e], ['268', 0x4f2170], ['269', 0x442359],
  ['2635', 0xc9add8], ['2645', 0xb591d1], ['2655', 0x9b6dc6], ['2665', 0x894fbf], ['Violet', 0x6607a5], ['2685', 0x56008c], ['2695', 0x44235e],
  ['270', 0xbaafd3], ['271', 0x9e91c6], ['272', 0x8977ba], ['273', 0x38197a], ['274', 0x2b1166], ['275', 0x260f54], ['276', 0x2b2147],
  ['2705', 0xad9ed3], ['2715', 0x937acc], ['2725', 0x7251bc], ['2735', 0x4f0093], ['2745', 0x3f0077], ['2755', 0x35006d], ['2765', 0x2b0c56],
  ['2706', 0xd1cedd], ['2716', 0xa5a0d6], ['2726', 0x6656bc], ['2736', 0x4930ad], ['2746', 0x3f2893], ['2756', 0x332875], ['2766', 0x2b265b],
  ['2707', 0xbfd1e5], ['2717', 0xa5bae0], ['2727', 0x5e68c4], ['Blue072', 0x380096], ['2747', 0x1c146b], ['2757', 0x141654], ['2767', 0x14213d],
  ['2708', 0xafbcdb], ['2718', 0x5b77cc], ['2728', 0x3044b5], ['2738', 0x2d008e], ['2748', 0x1e1c77], ['2758', 0x192168], ['2768', 0x112151],
  ['277', 0xb5d1e8], ['278', 0x99badd], ['279', 0x6689cc], ['Reflex Blue', 0x0c1c8c], ['280', 0x002b7f], ['281', 'Navy Blue', 'US Flag Blux', 0x002868], ['282', 0x002654],
  ['283', 0x9bc4e2], ['284', 0x75aadb], ['285', 0x3a75c4], ['286', 0x0038a8], ['287', 'Medium Blue', 0x003893], ['288', 0x00337f], ['289', 'Navy Blue', 0x002649],
  ['290', 0xc4d8e2], ['291', 0xa8cee2], ['292', 0x75b2dd], ['293', 'Royal Blue', 0x0051ba], ['294', 0x003f87], ['295', 0x00386b], ['296', 0x002d47],
  ['2905', 0x93c6e0], ['2915', 0x60afdd], ['2925', 'Light Blue', 0x008ed6], ['2935', 'Royal Blue', 0x005bbf], ['2945', 0x0054a0], ['2955', 0x003d6b], ['2965', 0x00334c],
  ['297', 0x82c6e2], ['298', 0x51b5e0], ['299', 0x00a3dd], ['300', 'Royal Blue', 0x0072c6], ['301', 0x005b99], ['302', 0x004f6d], ['303', 0x003f54],
  ['2975', 0xbae0e2], ['2985', 0x51bfe2], ['2995', 0x00a5db], ['3005', 0x0084c9], ['3015', 0x00709e], ['3025', 0x00546b], ['3035', 0x004454],
  ['304', 0xa5dde2], ['305', 0x70cee2], ['306', 0x00bce2], ['Process Blue', 0x0091c9], ['307', 0x007aa5], ['308', 0x00607c], ['309', 0x003f49],
  ['310', 0x72d1dd], ['311', 0x28c4d8], ['312', 0x00adc6], ['313', 0x0099b5], ['314', 0x00829b], ['315', 0x006b77], ['316', 'Dark Teal', 0x00494f],
  ['3105', 0x7fd6db], ['3115', 0x2dc6d6], ['3125', 0x00b7c6], ['3135', 0x009baa], ['3145', 0x00848e], ['3155', 0x006d75], ['3165', 0x00565b],
  ['317', 0xc9e8dd], ['318', 0x93dddb], ['319', 0x4cced1], ['320', 'Teal', 0x009ea0], ['321', 0x008789], ['322', 0x007272], ['323', 0x006663],
  ['324', 0xaaddd6], ['325', 0x56c9c1], ['326', 0x00b2aa], ['327', 'Teal', 0x008c82], ['328', 0x007770], ['329', 0x006d66], ['330', 0x005951],
  ['3242', 0x87ddd1], ['3252', 0x56d6c9], ['3262', 0x00c1b5], ['3272', 0x00aa9e], ['3282', 0x008c82], ['3292', 0x006056], ['3302', 0x00493f],
  ['3245', 0x8ce0d1], ['3255', 0x47d6c1], ['3265', 0x00c6b2], ['3275', 0x00b2a0], ['3285', 0x009987], ['3295', 0x008272], ['3305', 'Dark Green', 0x004f42],
  ['3248', 0x7ad3c1], ['3258', 0x35c4af], ['3268', 0x00af99], ['3278', 0x009b84], ['3288', 0x008270], ['3298', 0x006b5b], ['3308', 0x004438],
  ['331', 0xbaead6], ['332', 0xa0e5ce], ['333', 0x5eddc1], ['Green', 0x00af93], ['334', 0x00997c], ['335', 0x007c66], ['336', 0x006854],
  ['337', 0x9bdbc1], ['338', 0x7ad1b5], ['339', 0x00b28c], ['340', 'Light Green', 0x009977], ['341', 'Forest Green', 0x007a5e], ['342', 'Forest Green', 0x006b54], ['343', 'Dark Green', 0x00563f],
  ['3375', 0x8ee2bc], ['3385', 0x54d8a8], ['3395', 0x00c993], ['3405', 0x00b27a], ['3415', 0x007c59], ['3425', 0x006847], ['3435', 0x024930],
  ['344', 0xb5e2bf], ['345', 0x96d8af], ['346', 0x70ce9b], ['347', 'Medium Green', 0x009e60], ['348', 0x008751], ['349', 'Kelly Green', 0x006b3f], ['350', 0x234f33],
  ['351', 0xb5e8bf], ['352', 0x99e5b2], ['353', 0x84e2a8], ['354', 'Light Green', 0x00b760], ['355', 'Green', 0x009e49], ['356', 0x007a3d], ['357', 'Forest Green', 0x215b33],
  ['358', 0xaadd96], ['359', 0xa0db8e], ['360', 0x60c659], ['361', 0x1eb53a], ['362', 0x339e35], ['363', 0x3d8e33], ['364', 0x3a7728],
  ['365', 0xd3e8a3], ['366', 0xc4e58e], ['367', 0xaadd6d], ['368', 0x5bbf21], ['369', 0x56aa1c], ['370', 0x568e14], ['371', 0x566b21],
  ['372', 0xd8ed96], ['373', 0xceea82], ['374', 0xbae860], ['375', 0x8cd600], ['376', 0x7fba00], ['377', 0x709302], ['378', 0x566314],
  ['379', 0xe0ea68], ['380', 0xd6e542], ['381', 0xcce226], ['382', 0xbad80a], ['383', 0xa3af07], ['384', 0x939905], ['385', 0x707014],
  ['386', 0xe8ed60], ['387', 0xe0ed44], ['388', 0xd6e80f], ['389', 0xcee007], ['390', 0xbac405], ['391', 0x9e9e07], ['392', 0x848205],
  ['393', 0xf2ef87], ['394', 0xeaed35], ['395', 0xe5e811], ['396', 0xe0e20c], ['397', 0xc1bf0a], ['398', 0xafa80a], ['399', 0x998e07],
  ['3935', 0xf2ed6d], ['3945', 0xefea07], ['3955', 0xede211], ['3965', 0xe8dd11], ['3975', 0xb5a80c], ['3985', 0x998c0a], ['3995', 0x6d6002],
  ['400', 0xd1c6b5], ['401', 0xc1b5a5], ['402', 0xafa593], ['403', 0x998c7c], ['404', 0x827566], ['405', 0x6b5e4f], ['Black', 0x3d332b],
  ['406', 0xcec1b5], ['407', 0xbaaa9e], ['408', 0xa8998c], ['409', 0x99897c], ['410', 0x7c6d63], ['411', 0x66594c], ['412', 0x3d3028],
  ['413', 0xc6c1b2], ['414', 0xb5afa0], ['415', 0xa39e8c], ['416', 0x8e8c7a], ['417', 0x777263], ['418', 0x605e4f], ['419', 0x282821],
  ['420', 0xd1ccbf], ['421', 0xbfbaaf], ['422', 0xafaaa3], ['423', 'Gray', 0x96938e], ['424', 'Charcoal Gray', 0x827f77], ['425', 0x60605b], ['426', 0x2b2b28],
  ['427', 0xdddbd1], ['428', 'Gray', 0xd1cec6], ['429', 0xadafaa], ['430', 'Charcoal', 0x919693], ['431', 'Dark Grey', 0x666d70], ['432', 0x444f51], ['433', 0x30383a],
  ['434', 0xe0d1c6], ['435', 0xd3bfb7], ['436', 0xbca59e], ['437', 0x8c706b], ['438', 0x593f3d], ['439', 0x493533], ['440', 0x3f302b],
  ['441', 0xd1d1c6], ['442', 0xbabfb7], ['443', 0xa3a8a3], ['444', 0x898e8c], ['445', 0x565959], ['446', 0x494c49], ['447', 0x3f3f38],
  ['WarmGray 1', 0xe5dbcc], ['WarmGray 2', 0xddd1c1], ['WarmGray 3', 0xccc1b2], ['WarmGray 4', 0xc1b5a5], ['WarmGray 5', 0xb5a899], ['WarmGray 6', 0xafa393], ['WarmGray 7', 0xa39687],
  ['WarmGray 8', 0x96897a], ['WarmGray 9', 0x8c7f70], ['WarmGray 10', 0x827263], ['WarmGray 11', 0x6d5e51], ['CoolGray 1', 0xe8e2d6], ['CoolGray 2', 0xddd8ce], ['CoolGray 3', 0xd3cec4],
  ['CoolGray 4', 0xc4c1ba], ['CoolGray 5', 0xbab7af], ['CoolGray 6', 0xb5b2aa], ['CoolGray 7', 0xa5a39e], ['CoolGray 8', 0x9b9993], ['CoolGray 9', 0x8c8984], ['CoolGray 10', 0x777772],
  ['CoolGray 11', 0x686663], ['448', 0x54472d], ['449', 0x544726], ['450', 0x60542b], ['451', 0xada07a], ['452', 0xc4b796], ['453', 0xd6ccaf],
  ['454', 0xe2d8bf], ['4485', 0x604c11], ['4495', 0x877530], ['4505', 0xa09151], ['4515', 0xbcad75], ['4525', 0xccbf8e], ['4535', 0xdbcea5],
  ['4545', 0xe5dbba], ['455', 0x665614], ['456', 0x998714], ['457', 0xb59b0c], ['458', 0xddcc6b], ['459', 0xe2d67c], ['460', 0xeadd96],
  ['461', 0xede5ad], ['462', 0x5b4723], ['463', 0x755426], ['464', 0x876028], ['465', 0xc1a875], ['466', 0xd1bf91], ['467', 0xddcca5],
  ['468', 0xe2d6b5], ['4625', 0x472311], ['4635', 'Brown', 0x8c5933], ['4645', 0xb28260], ['4655', 0xc49977], ['4665', 0xd8b596], ['4675', 0xe5c6aa],
  ['4685', 0xedd3bc], ['469', 'Brown', 0x603311], ['4695', 0x51261c], ['4705', 0x7c513d], ['4715', 0x99705b], ['4725', 0xb5917c], ['4735', 0xccaf9b],
  ['4745', 0xd8bfaa], ['4755', 0xe2ccba], ['476', 'Brown', 0x593d2b], ['477', 0x633826], ['478', 0x7a3f28], ['479', 0xaf8970], ['480', 0xd3b7a3],
  ['481', 0xe0ccba], ['482', 0xe5d3c1], ['483', 0x6b3021], ['484', 0x9b301c], ['485', 0xd81e05], ['486', 0xed9e84], ['487', 0xefb5a0],
  ['488', 0xf2c4af], ['489', 0xf2d1bf], ['490', 0x5b2626], ['491', 0x752828], ['492', 0x913338], ['493', 0xdb828c], ['494', 0xf2adb2],
  ['495', 0xf4bcbf], ['496', 0xf7c9c6], ['497', 0x512826], ['498', 0x6d332b], ['499', 0x7a382d], ['500', 0xce898c], ['501', 0xeab2b2],
  ['502', 0xf2c6c4], ['503', 0xf4d1cc], ['4975', 0x441e1c], ['4985', 0x844949], ['4995', 0xa56b6d], ['5005', 0xbc8787], ['5015', 0xd8ada8],
  ['5025', 0xe2bcb7], ['5035', 0xedcec6], ['504', 0x511e26], ['505', 0x661e2b], ['506', 0x7a2638], ['507', 0xd8899b], ['508', 0xe8a5af],
  ['509', 0xf2babf], ['510', 0xf4c6c9], ['511', 0x602144], ['512', 0x84216b], ['513', 0x9e2387], ['514', 0xd884bc], ['515', 0xe8a3c9],
  ['516', 0xf2bad3], ['517', 0xf4ccd8], ['5115', 0x4f213a], ['5125', 0x754760], ['5135', 0x936b7f], ['5145', 0xad8799], ['5155', 0xccafb7],
  ['5165', 0xe0c9cc], ['5175', 0xe8d6d1], ['518', 0x512d44], ['519', 0x63305e], ['520', 0x703572], ['521', 0xb58cb2], ['522', 0xc6a3c1],
  ['523', 0xd3b7cc], ['524', 0xe2ccd3], ['5185', 0x472835], ['5195', 0x593344], ['5205', 0x8e6877], ['5215', 0xb5939b], ['5225', 0xccadaf],
  ['5235', 0xddc6c4], ['5245', 0xe5d3cc], ['525', 0x512654], ['526', 0x68217a], ['527', 0x7a1e99], ['528', 0xaf72c1], ['529', 0xcea3d3],
  ['530', 0xd6afd6], ['531', 0xe5c6db], ['5255', 0x35264f], ['5265', 0x493d63], ['5275', 0x605677], ['5285', 0x8c8299], ['5295', 0xb2a8b5],
  ['5305', 0xccc1c6], ['5315', 0xdbd3d3], ['532', 0x353842], ['533', 0x353f5b], ['534', 0x3a4972], ['535', 0x9ba3b7], ['536', 0xadb2c1],
  ['537', 0xc4c6ce], ['538', 0xd6d3d6], ['539', 0x003049], ['540', 0x00335b], ['541', 0x003f77], ['542', 0x6693bc], ['543', 0x93b7d1],
  ['544', 0xb7ccdb], ['545', 0xc4d3dd], ['5395', 0x02283a], ['5405', 0x3f6075], ['5415', 0x607c8c], ['5425', 0x8499a5], ['5435', 0xafbcbf],
  ['5445', 0xc4cccc], ['5455', 0xd6d8d3], ['546', 0x0c3844], ['547', 0x003f54], ['548', 0x004459], ['549', 0x5e99aa], ['550', 0x87afbf],
  ['551', 0xa3c1c9], ['552', 0xc4d6d6], ['5463', 0x00353a], ['5473', 0x26686d], ['5483', 0x609191], ['5493', 0x8cafad], ['5503', 0xaac4bf],
  ['5513', 0xced8d1], ['5523', 0xd6ddd6], ['5467', 0x193833], ['5477', 0x3a564f], ['5487', 0x667c72], ['5497', 0x91a399], ['5507', 0xafbab2],
  ['5517', 0xc9cec4], ['5527', 0xced1c6], ['553', 0x234435], ['554', 0x195e47], ['555', 0x076d54], ['556', 0x7aa891], ['557', 0xa3c1ad],
  ['558', 0xb7cebc], ['559', 0xc6d6c4], ['5535', 0x213d30], ['5545', 0x4f6d5e], ['5555', 0x779182], ['5565', 0x96aa99], ['5575', 0xafbfad],
  ['5585', 0xc4cebf], ['5595', 0xd8dbcc], ['560', 0x2b4c3f], ['561', 0x266659], ['562', 0x1e7a6d], ['563', 0x7fbcaa], ['564', 0xa0cebc],
  ['565', 0xbcdbcc], ['566', 0xd1e2d3], ['5605', 0x233a2d], ['5615', 0x546856], ['5625', 0x728470], ['5635', 0x9eaa99], ['5645', 0xbcc1b2],
  ['5655', 0xc6ccba], ['568', 0xd6d6c6], ['569', 'Metallic Green', 0x05705e], ['570', 0x008772], ['571', 0x7fc6b2], ['572', 0xaadbc6], ['573', 0xbce2ce],
  ['574', 0xcce5d6], ['575', 0x495928], ['576', 0x547730], ['577', 0x608e3a], ['578', 0xb5cc8e], ['579', 0xc6d6a0], ['580', 0xc9d6a3],
  ['5743', 0xd8ddb5], ['5753', 0x3f4926], ['5763', 0x5e663a], ['5773', 0x777c4f], ['5783', 0x9b9e72], ['5793', 0xb5b58e], ['803', 0xc6c6a5],
  ['5747', 0xd8d6b7], ['5757', 0x424716], ['5767', 0x6b702b], ['5777', 0x8c914f], ['5787', 0xaaad75], ['5797', 0xc6c699], ['5807', 0xd3d1aa],
  ['581', 0xe0ddbc], ['582', 0x605e11], ['583', 0x878905], ['584', 0xaaba0a], ['585', 0xdbe06b], ['586', 0xe2e584], ['587', 0xe8e89b],
  ['5815', 0x494411], ['5825', 0x75702b], ['5835', 0x9e9959], ['5845', 0xb2aa70], ['5855', 0xccc693], ['5865', 0xd6cea3], ['5875', 0xe0dbb5],
  ['600', 0xf4edaf], ['601', 0xf2ed9e], ['602', 0xf2ea87], ['603', 0xede85b], ['604', 0xe8dd21], ['605', 0xddce11], ['606', 0xd3bf11],
  ['607', 0xf2eabc], ['608', 0xefe8ad], ['609', 0xeae596], ['610', 0xe2db72], ['611', 0xd6ce49], ['612', 0xc4ba00], ['613', 0xafa00c],
  ['614', 0xeae2b7], ['615', 0xe2dbaa], ['616', 0xddd69b], ['617', 0xccc47c], ['618', 0xb5aa59], ['619', 0x968c28], ['620', 0x847711],
  ['621', 0xd8ddce], ['622', 0xc1d1bf], ['623', 0xa5bfaa], ['624', 0x7fa08c], ['625', 0x5b8772], ['626', 0x21543f], ['627', 0x0c3026],
  ['628', 0xcce2dd], ['629', 0xb2d8d8], ['630', 0x8cccd3], ['631', 0x54b7c6], ['632', 0x00a0ba], ['633', 0x007f99], ['634', 0x00667f],
  ['635', 0xbae0e0], ['636', 0x99d6dd], ['637', 0x6bc9db], ['638', 0x00b5d6], ['639', 0x00a0c4], ['640', 0x008cb2], ['641', 0x007aa5],
  ['642', 0xd1d8d8], ['643', 0xc6d1d6], ['644', 0x9bafc4], ['645', 0x7796b2], ['646', 0x5e82a3], ['647', 0x26547c], ['648', 0x00305e],
  ['649', 0xd6d6d8], ['650', 0xbfc6d1], ['651', 0x9baabf], ['652', 0x6d87a8], ['653', 0x335687], ['654', 0x0f2b5b], ['655', 0x0c1c47],
  ['656', 0xd6dbe0], ['657', 0xc1c9dd], ['658', 0xa5afd6], ['659', 0x7f8cbf], ['660', 0x5960a8], ['661', 0x2d338e], ['662', 0x0c1975],
  ['663', 0xe2d3d6], ['664', 0xd8ccd1], ['665', 0xc6b5c4], ['666', 0xa893ad], ['667', 0x7f6689], ['668', 0x664975], ['669', 0x472b59],
  ['670', 0xf2d6d8], ['671', 0xefc6d3], ['672', 0xeaaac4], ['673', 0xe08cb2], ['674', 0xd36b9e], ['675', 0xbc3877], ['676', 0xa00054],
  ['677', 0xedd6d6], ['678', 0xeaccce], ['679', 0xe5bfc6], ['680', 0xd39eaf], ['681', 0xb7728e], ['682', 0xa05175], ['683', 0x7f284f],
  ['684', 0xefccce], ['685', 0xeabfc4], ['686', 0xe0aaba], ['687', 0xc9899e], ['688', 0xb26684], ['689', 0x934266], ['690', 0x702342],
  ['691', 0xefd1c9], ['692', 0xe8bfba], ['693', 0xdba8a5], ['694', 0xc98c8c], ['695', 0xb26b70], ['696', 0x8e4749], ['697', 0x7f383a],
  ['698', 0xf7d1cc], ['699', 0xf7bfbf], ['700', 0xf2a5aa], ['701', 0xe8878e], ['702', 0xd6606d], ['703', 0xb73844], ['704', 0x9e2828],
  ['705', 0xf9ddd6], ['706', 0xfcc9c6], ['707', 0xfcadaf], ['708', 0xf98e99], ['709', 0xf26877], ['710', 0xe04251], ['711', 0xd12d33],
  ['712', 0xffd3aa], ['713', 0xf9c9a3], ['714', 0xf9ba82], ['715', 0xfc9e49], ['716', 0xf28411], ['717', 0xd36d00], ['718', 0xbf5b00],
  ['719', 0xf4d1af], ['720', 0xefc49e], ['721', 0xe8b282], ['722', 0xd18e54], ['723', 0xba7530], ['724', 0x8e4905], ['725', 0x753802],
  ['726', 0xedd3b5], ['727', 0xe2bf9b], ['728', 0xd3a87c], ['729', 0xc18e60], ['730', 0xaa753f], ['731', 0x723f0a], ['732', 0x60330a],
  ['7468', 'Metallic Blue', 0x00759A], ['7433', 'Metallic Magenta', 0xA84069],
  ['Yellow 2X', 0xfce216], ['116 2X', 0xf7b50c], ['130 2X', 0xe29100], ['165 2X', 0xea4f00], ['WarmRed 2X', 0xe03a00], ['1788 2X', 0xd62100], ['1852 2X', 0xd11600],
  ['485 2X', 0xcc0c00], ['Rubine Red 2X', 0xc6003d], ['Rhodamine Red 2X', 0xd10572], ['239 2X', 0xc4057c], ['Purple 2X', 0xaa0096], ['2592 2X', 0x720082], ['Violet 2X', 0x59008e],
  ['Reflex Blue 2X', 0x1c007a], ['Process Blue 2X', 0x0077bf], ['299 2X', 0x007fcc], ['306 2X', 0x00a3d1], ['320 2X', 0x007f82], ['327 2X', 0x008977], ['Green2X', 0x009677],
  ['354 2X', 0x009944], ['368 2X', 0x009e0f], ['375 2X', 0x54bc00], ['382 2X', 0x9ec400], ['471 2X', 0xa34402], ['464 2X', 0x704214], ['433 2X', 0x0a0c11],
  ['Black2', 0x3a3321], ['Black3', 0x282d26], ['Black4', 0x3d3023], ['Black5', 0x422d2d], ['Black6', 0x1c2630], ['Black7', 0x443d38], ['Black2 2X', 0x111111],
  ['Black3 2X', 0x111114], ['Black4 2X', 0x0f0f0f], ['Black5 2X', 0x110c0f], ['Black6 2X', 0x070c0f], ['Black7 2X', 0x33302b], ['801', 0x00aacc], ['802', 0x60dd49],
  ['803', 0xffed38], ['804', 0xff9338], ['805', 0xf95951], ['806', 0xff0093], ['807', 0xd6009e], ['801 2X', 0x0089af], ['802 2X', 0x1cce28],
  ['803 2X', 0xffd816], ['804 2X', 0xff7f1e], ['805 2X', 0xf93a2b], ['806 2X', 0xf7027c], ['807 2X', 0xbf008c], ['808', 0x00b59b], ['809', 0xdde00f],
  ['810', 0xffcc1e], ['811', 0xff7247], ['812', 0xfc2366], ['813', 0xe50099], ['814', 0x8c60c1], ['808 2X', 0x00a087], ['809 2X', 0xd6d60c],
  ['810 2X', 0xffbc21], ['811 2X', 0xff5416], ['812 2X', 0xfc074f], ['813 2X', 0xd10084], ['814 2X', 0x703faf],
  ['877', 'Silver', 0x85868b], ['871', 'Gold', 0xa39262], ['872', 'Metallic Gold', 0x87654a], ['873', 'Metallic Gold', 0x87654a], ['874', 'Metallic Gold', 0x87654a], ['Black', 0x000000], ['876', 'Bronze', 0xba8747], ['White', 0xffffff],
]
  end
end
