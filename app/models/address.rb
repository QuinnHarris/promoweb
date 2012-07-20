class Address < ActiveRecord::Base
#  validates_presence_of :postalcode

  before_save :update_address
  def update_address
    if address1.blank? and !address2.blank?
      self.address1 = address2
      self.address2 = nil
    end
  end

  @@postal_8dig = /^\d{5}(-\d{4})?$/
  @@postal_regex = {
    'US' => @@postal_8dig,
    'PR' => @@postal_8dig,
    'CA' => /^\w\d\w\s*\d\w\d$/,
    'NL' => /^\d{4}\s?[A-Z]{2}$/i,
    'IN' => /^\d{6}$/,
    'GB' => /(GIR 0AA)|(((A[BL]|B[ABDHLNRSTX]?|C[ABFHMORTVW]|D[ADEGHLNTY]|E[HNX]?|F[KY]|G[LUY]?|H[ADGPRSUX]|I[GMPV]|JE|K[ATWY]|L[ADELNSU]?|M[EKL]?|N[EGNPRW]?|O[LX]|P[AEHLOR]|R[GHM]|S[AEGKLMNOPRSTY]?|T[ADFNQRSW]|UB|W[ADFNRSV]|YO|ZE)[1-9]?[0-9]|((E|N|NW|SE|SW|W)1|EC[1-4]|WC[12])[A-HJKMNPR-Y]|(SW|W)([2-9]|[1-9][0-9])|EC[1-9][0-9]) [0-9][ABD-HJLNP-UW-Z]{2})/i
  }

  def invalid_postal?
    reg = @@postal_regex[country]
    return "unknown country: #{country}" unless reg

    return "blank postalcode" if postalcode.blank?

    return nil if reg === postalcode
    return "invalid postal format: #{postalcode} != #{reg}"
  end

  def incomplete?
    %w(address1 city state postalcode).find_all do |name|
      send(name).blank?
    end
  end

  def country_name
    COUNTRY_HASH[country]
  end

  def UPSAddress
    address = UPS::Shipping::Address.new
    address.city = city if city
    if state
      region = Region.find_by_name(state)
      address.province = region.abrev if region
    end
    address.postalcode = postalcode
    address.country = country
    address.lines = [address1, address2].compact
    address
  end
end


country_src = %q(O1,"Other Country"
AD,"Andorra"
AE,"United Arab Emirates"
AF,"Afghanistan"
AG,"Antigua and Barbuda"
AI,"Anguilla"
AL,"Albania"
AM,"Armenia"
AN,"Netherlands Antilles"
AO,"Angola"
AP,"Asia/Pacific Region"
AQ,"Antarctica"
AR,"Argentina"
AS,"American Samoa"
AT,"Austria"
AU,"Australia"
AW,"Aruba"
AX,"Aland Islands"
AZ,"Azerbaijan"
BA,"Bosnia and Herzegovina"
BB,"Barbados"
BD,"Bangladesh"
BE,"Belgium"
BF,"Burkina Faso"
BG,"Bulgaria"
BH,"Bahrain"
BI,"Burundi"
BJ,"Benin"
BL,"Saint Bartelemey"
BM,"Bermuda"
BN,"Brunei Darussalam"
BO,"Bolivia"
BR,"Brazil"
BS,"Bahamas"
BT,"Bhutan"
BV,"Bouvet Island"
BW,"Botswana"
BY,"Belarus"
BZ,"Belize"
CA,"Canada"
CC,"Cocos (Keeling) Islands"
CD,"Congo, The Democratic Republic of the"
CF,"Central African Republic"
CG,"Congo"
CH,"Switzerland"
CI,"Cote d'Ivoire"
CK,"Cook Islands"
CL,"Chile"
CM,"Cameroon"
CN,"China"
CO,"Colombia"
CR,"Costa Rica"
CU,"Cuba"
CV,"Cape Verde"
CX,"Christmas Island"
CY,"Cyprus"
CZ,"Czech Republic"
DE,"Germany"
DJ,"Djibouti"
DK,"Denmark"
DM,"Dominica"
DO,"Dominican Republic"
DZ,"Algeria"
EC,"Ecuador"
EE,"Estonia"
EG,"Egypt"
EH,"Western Sahara"
ER,"Eritrea"
ES,"Spain"
ET,"Ethiopia"
EU,"Europe"
FI,"Finland"
FJ,"Fiji"
FK,"Falkland Islands (Malvinas)"
FM,"Micronesia, Federated States of"
FO,"Faroe Islands"
FR,"France"
FX,"France, Metropolitan"
GA,"Gabon"
GB,"United Kingdom"
GD,"Grenada"
GE,"Georgia"
GF,"French Guiana"
GG,"Guernsey"
GH,"Ghana"
GI,"Gibraltar"
GL,"Greenland"
GM,"Gambia"
GN,"Guinea"
GP,"Guadeloupe"
GQ,"Equatorial Guinea"
GR,"Greece"
GS,"South Georgia and the South Sandwich Islands"
GT,"Guatemala"
GU,"Guam"
GW,"Guinea-Bissau"
GY,"Guyana"
HK,"Hong Kong"
HM,"Heard Island and McDonald Islands"
HN,"Honduras"
HR,"Croatia"
HT,"Haiti"
HU,"Hungary"
ID,"Indonesia"
IE,"Ireland"
IL,"Israel"
IM,"Isle of Man"
IN,"India"
IO,"British Indian Ocean Territory"
IQ,"Iraq"
IR,"Iran, Islamic Republic of"
IS,"Iceland"
IT,"Italy"
JE,"Jersey"
JM,"Jamaica"
JO,"Jordan"
JP,"Japan"
KE,"Kenya"
KG,"Kyrgyzstan"
KH,"Cambodia"
KI,"Kiribati"
KM,"Comoros"
KN,"Saint Kitts and Nevis"
KP,"Korea, Democratic People's Republic of"
KR,"Korea, Republic of"
KW,"Kuwait"
KY,"Cayman Islands"
KZ,"Kazakhstan"
LA,"Lao People's Democratic Republic"
LB,"Lebanon"
LC,"Saint Lucia"
LI,"Liechtenstein"
LK,"Sri Lanka"
LR,"Liberia"
LS,"Lesotho"
LT,"Lithuania"
LU,"Luxembourg"
LV,"Latvia"
LY,"Libyan Arab Jamahiriya"
MA,"Morocco"
MC,"Monaco"
MD,"Moldova, Republic of"
ME,"Montenegro"
MF,"Saint Martin"
MG,"Madagascar"
MH,"Marshall Islands"
MK,"Macedonia"
ML,"Mali"
MM,"Myanmar"
MN,"Mongolia"
MO,"Macao"
MP,"Northern Mariana Islands"
MQ,"Martinique"
MR,"Mauritania"
MS,"Montserrat"
MT,"Malta"
MU,"Mauritius"
MV,"Maldives"
MW,"Malawi"
MX,"Mexico"
MY,"Malaysia"
MZ,"Mozambique"
NA,"Namibia"
NC,"New Caledonia"
NE,"Niger"
NF,"Norfolk Island"
NG,"Nigeria"
NI,"Nicaragua"
NL,"Netherlands"
NO,"Norway"
NP,"Nepal"
NR,"Nauru"
NU,"Niue"
NZ,"New Zealand"
OM,"Oman"
PA,"Panama"
PE,"Peru"
PF,"French Polynesia"
PG,"Papua New Guinea"
PH,"Philippines"
PK,"Pakistan"
PL,"Poland"
PM,"Saint Pierre and Miquelon"
PN,"Pitcairn"
PR,"Puerto Rico"
PS,"Palestinian Territory"
PT,"Portugal"
PW,"Palau"
PY,"Paraguay"
QA,"Qatar"
RE,"Reunion"
RO,"Romania"
RS,"Serbia"
RU,"Russian Federation"
RW,"Rwanda"
SA,"Saudi Arabia"
SB,"Solomon Islands"
SC,"Seychelles"
SD,"Sudan"
SE,"Sweden"
SG,"Singapore"
SH,"Saint Helena"
SI,"Slovenia"
SJ,"Svalbard and Jan Mayen"
SK,"Slovakia"
SL,"Sierra Leone"
SM,"San Marino"
SN,"Senegal"
SO,"Somalia"
SR,"Suriname"
ST,"Sao Tome and Principe"
SV,"El Salvador"
SY,"Syrian Arab Republic"
SZ,"Swaziland"
TC,"Turks and Caicos Islands"
TD,"Chad"
TF,"French Southern Territories"
TG,"Togo"
TH,"Thailand"
TJ,"Tajikistan"
TK,"Tokelau"
TL,"Timor-Leste"
TM,"Turkmenistan"
TN,"Tunisia"
TO,"Tonga"
TR,"Turkey"
TT,"Trinidad and Tobago"
TV,"Tuvalu"
TW,"Taiwan"
TZ,"Tanzania, United Republic of"
UA,"Ukraine"
UG,"Uganda"
UM,"United States Minor Outlying Islands"
US,"United States"
UY,"Uruguay"
UZ,"Uzbekistan"
VA,"Holy See (Vatican City State)"
VC,"Saint Vincent and the Grenadines"
VE,"Venezuela"
VG,"Virgin Islands, British"
VI,"Virgin Islands, U.S."
VN,"Vietnam"
VU,"Vanuatu"
WF,"Wallis and Futuna"
WS,"Samoa"
YE,"Yemen"
YT,"Mayotte"
ZA,"South Africa"
ZM,"Zambia"
ZW,"Zimbabwe")

Address::COUNTRY_LIST = country_src.split("\n").collect do |l|
  raise "Unknown: #{l}" unless /^(\w{2}),\"(.+)\"$/ === l
  [$2, $1]
end.sort_by { |name, code| name }

Address::COUNTRY_HASH = Address::COUNTRY_LIST.each_with_object({}) do |(v, k), hash|
  hash[k] = v
end
