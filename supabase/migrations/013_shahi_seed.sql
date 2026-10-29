-- SHAHI starting content, taken from the brand's own Facebook posts.
-- Meal-prep prices are left empty on purpose (the site shows "تواصل معانا" until they are set).

insert into public.shahi_settings (key, value) values
  ('public.whatsapp_number', '201111126938'),
  ('public.whatsapp_text', 'عايز أعرف منيو عزومات شاهي'),
  ('public.meta_pixel_id', null),
  ('public.service_areas', '6 أكتوبر، الشيخ زايد'),
  ('public.email', 'shahifoodegypt@gmail.com')
on conflict (key) do nothing;

with items(name_ar, name_en, description_ar, description_en, category, sort) as (values
  ('طبق شاهي للعزومات', 'Shahi gathering platter',
   'روستو بيف بالشيدر الأحمر • فراخ بانيه • ميني بيتزا • حلو تركي بعين الجمل • سلطة خس وفلفل ألوان',
   'Roast beef with red cheddar • chicken panée • mini pizza • Turkish walnut dessert • lettuce & pepper salad', 'gathering', 1),
  ('رولات سموك سالمون', 'Smoked salmon rolls',
   'محشية كريم تشيز بالشبت، مع كابرز على جرجير فريش وبرتقال',
   'Filled with dill cream cheese, capers, fresh rocket and orange', 'gathering', 2),
  ('كروكيت بطاطس بالفراخ', 'Chicken potato croquettes',
   'مقرمشة بالبانكو، فوقها بنجر وبارميزان على ميكروجرين',
   'Panko-crusted, topped with beetroot and parmesan on microgreens', 'gathering', 3),
  ('بط محمّر بصوص البرتقال', 'Roast duck with orange sauce', null, null, 'a_la_carte', 10),
  ('ديك رومي بالفريك والمكسرات', 'Turkey with freekeh and nuts', null, null, 'a_la_carte', 11),
  ('محاشي وورق عنب بلمسة شيف', 'Chef''s stuffed vegetables & vine leaves', null, null, 'a_la_carte', 12),
  ('كفتة وريش على الفحم', 'Charcoal kofta & lamb chops', null, null, 'a_la_carte', 13),
  ('فيليه بصوص الترافل', 'Beef fillet with truffle sauce', null, null, 'a_la_carte', 14),
  ('سالمون وجمبري جامبو', 'Salmon & jumbo shrimp', null, null, 'a_la_carte', 15)
)
insert into public.shahi_menu_items (name_ar, name_en, description_ar, description_en, category, sort)
select * from items i where not exists (select 1 from public.shahi_menu_items m where m.name_ar = i.name_ar);

with pk(name_ar, name_en, guests, price, old_price, highlight, sort) as (values
  ('باكدج 15 فرد', '15-guest package', 15, 13500, 15000, false, 1),
  ('باكدج 25 فرد', '25-guest package', 25, 21600, 24000, true, 2),
  ('باكدج 35 فرد', '35-guest package', 35, 28800, 32000, false, 3)
)
insert into public.shahi_packages (name_ar, name_en, guests, price, old_price, highlight, sort)
select * from pk where not exists (select 1 from public.shahi_packages p where p.guests = pk.guests);

insert into public.shahi_package_items (package_id, menu_item_id, sort)
select p.id, m.id, m.sort from public.shahi_packages p cross join public.shahi_menu_items m
where m.category = 'gathering'
on conflict do nothing;

with mp(name_ar, name_en, period, meals_per_day, sort) as (values
  ('اشتراك أسبوعي', 'Weekly plan', 'weekly', null::int, 1),
  ('اشتراك شهري', 'Monthly plan', 'monthly', null::int, 2)
)
insert into public.shahi_meal_plans (name_ar, name_en, period, meals_per_day, sort)
select * from mp where not exists (select 1 from public.shahi_meal_plans x where x.period = mp.period);
