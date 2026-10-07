-- Arabic descriptions for the Home Sense products, shown to sales in the quotation picker.
alter table public.products add column if not exists description_ar text;

update public.products p set description_ar = v.ar
from (values
  ('1.25 inch','مقاس 1.25 بوصة'),('1080P','كاميرا 1080P'),('10A/13A/16A','10 / 13 / 16 أمبير'),
  ('2.0 N·m, up to 12m','قوة 2.0 نيوتن·متر، تراك لحد 12 متر'),('3A & 16A','3 أمبير و16 أمبير'),
  ('4.3" HD screen','شاشة HD مقاس 4.3 بوصة'),('4.3" screen','شاشة 4.3 بوصة'),('40A','40 أمبير'),
  ('Aluminum','ألومنيوم'),('Basic version','النسخة الأساسية'),('Black','أسود'),('Black/Brown','أسود/بني'),
  ('Black/Gold','أسود/دهبي'),('Black/Silver','أسود/فضي'),('Built-in Alexa + IR','Alexa مدمجة + تحكم IR'),
  ('Cat eye / normal version','بعين سحرية / نسخة عادية'),('Face + Palm vein, Zinc','بصمة وش + بصمة كف، زنك'),
  ('Glass panel, US/EU','واجهة زجاج، علبة أمريكي/أوروبي'),('Gold frame','إطار دهبي'),('Grey','رمادي'),
  ('IP66 Waterproof','ضد المياه IP66'),('LCD screen','بشاشة LCD'),('Max 150W LED','لحد 150 وات LED'),
  ('Motor + track','موتور + تراك'),('Peephole + indoor screen, video intercom','عين سحرية + شاشة داخلية، إنتركم فيديو'),
  ('Plug-in','بيتركب في البريزة'),('Red brown','بني محمر'),('Screen','بشاشة'),
  ('Up to 100 devices','لحد 100 جهاز'),('Up to 50 devices','لحد 50 جهاز'),
  ('Video intercom (doorbell-triggered)','إنتركم فيديو (بيشتغل مع الجرس)'),('With speakers','بسماعات'),('Zinc alloy','سبيكة زنك')
) v(en, ar)
where p.description = v.en;
