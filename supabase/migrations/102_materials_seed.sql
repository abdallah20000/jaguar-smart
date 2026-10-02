-- Jaguar Smart Materials: SAMPLE seed data. Every product, daily price and banner here is
-- flagged is_sample = true and shown as SAMPLE in the admin until it is replaced with real data.

insert into public.mat_areas (slug, governorate, name, name_ar, delivery_fee, delivery_days_min, delivery_days_max, sort) values
  ('cairo',        'Cairo', 'Cairo (Nasr City, Heliopolis, Maadi)', 'القاهرة',            750, 1, 2, 1),
  ('new-cairo',    'Cairo', 'New Cairo',                            'القاهرة الجديدة',     900, 1, 2, 2),
  ('new-capital',  'Cairo', 'New Administrative Capital',           'العاصمة الإدارية',   1200, 2, 3, 3),
  ('giza',         'Giza',  'Giza',                                 'الجيزة',              750, 1, 2, 4),
  ('october',      'Giza',  '6th of October',                       '6 أكتوبر',            900, 1, 2, 5),
  ('sheikh-zayed', 'Giza',  'Sheikh Zayed',                         'الشيخ زايد',          900, 1, 2, 6);

insert into public.mat_categories (slug, name, name_ar, icon, sort) values
  ('steel-rebar',      'Steel & rebar',       'حديد التسليح',        'steel',      1),
  ('cement',           'Cement',              'الأسمنت',             'cement',     2),
  ('bricks-blocks',    'Bricks & blocks',     'الطوب والبلوك',       'bricks',     3),
  ('sand-aggregates',  'Sand & aggregates',   'الرمل والزلط',        'sand',       4),
  ('tiles-ceramics',   'Tiles & ceramics',    'السيراميك والبورسلين', 'tiles',      5),
  ('paints',           'Paints',              'الدهانات',            'paint',      6),
  ('plumbing',         'Plumbing',            'السباكة',             'plumbing',   7),
  ('electrical',       'Electrical',          'الكهرباء',            'electrical', 8),
  ('gypsum-board',     'Gypsum board',        'الجبس بورد',          'gypsum',     9),
  ('insulation',       'Insulation',          'العزل',               'insulation', 10);

insert into public.mat_brands (slug, name, sort) values
  ('ezz-steel', 'Ezz Steel', 1), ('beshay-steel', 'Beshay Steel', 2), ('al-garhy-steel', 'Al Garhy Steel', 3),
  ('el-marakby-steel', 'El Marakby Steel', 4), ('suez-steel', 'Suez Steel', 5),
  ('suez-cement', 'Suez Cement', 6), ('arabian-cement', 'Arabian Cement', 7), ('sinai-white-cement', 'Sinai White Cement', 8),
  ('cleopatra-ceramics', 'Cleopatra Ceramics', 9), ('royal-ceramica', 'Royal Ceramica', 10),
  ('jotun', 'Jotun', 11), ('sipes', 'Sipes', 12), ('elsewedy-electric', 'Elsewedy Electric', 13),
  ('schneider-electric', 'Schneider Electric', 14), ('knauf', 'Knauf', 15), ('banninger', 'Bänninger', 16), ('sika', 'Sika', 17);

with p(slug, sku, name, cat, brand, unit, price, min_qty, step, featured, best, pop, descr, specs) as (values
  ('ezz-rebar-16mm', 'ST-EZZ-16', 'Ezz Steel Rebar 16 mm', 'steel-rebar', 'ezz-steel', 'ton', 39500, 1, 0.5, true, true, 95,
   'High-tensile deformed rebar for columns, beams and slabs. Delivered in 12 m bars.', '{"Grade":"B500DWR","Diameter":"16 mm","Bar length":"12 m","Standard":"ES 262/2015"}'),
  ('ezz-rebar-12mm', 'ST-EZZ-12', 'Ezz Steel Rebar 12 mm', 'steel-rebar', 'ezz-steel', 'ton', 39650, 1, 0.5, false, true, 90,
   'Deformed rebar for slabs and stirrups. Delivered in 12 m bars.', '{"Grade":"B500DWR","Diameter":"12 mm","Bar length":"12 m","Standard":"ES 262/2015"}'),
  ('beshay-rebar-16mm', 'ST-BSH-16', 'Beshay Steel Rebar 16 mm', 'steel-rebar', 'beshay-steel', 'ton', 38900, 1, 0.5, true, false, 70,
   'High-tensile deformed rebar. Delivered in 12 m bars.', '{"Grade":"B500DWR","Diameter":"16 mm","Bar length":"12 m"}'),
  ('al-garhy-rebar-12mm', 'ST-GRH-12', 'Al Garhy Steel Rebar 12 mm', 'steel-rebar', 'al-garhy-steel', 'ton', 38550, 1, 0.5, false, false, 45,
   'Deformed rebar for slabs and stirrups.', '{"Grade":"B500DWR","Diameter":"12 mm","Bar length":"12 m"}'),
  ('el-marakby-rebar-10mm', 'ST-MRK-10', 'El Marakby Steel Rebar 10 mm', 'steel-rebar', 'el-marakby-steel', 'ton', 38600, 1, 0.5, false, false, 35,
   'Light rebar for stirrups and secondary reinforcement.', '{"Grade":"B400","Diameter":"10 mm","Bar length":"12 m"}'),
  ('suez-steel-rebar-18mm', 'ST-SUZ-18', 'Suez Steel Rebar 18 mm', 'steel-rebar', 'suez-steel', 'ton', 38700, 1, 0.5, false, false, 40,
   'Heavy rebar for columns and foundations.', '{"Grade":"B500DWR","Diameter":"18 mm","Bar length":"12 m"}'),
  ('suez-cement-grey-bag', 'CM-SUZ-G50', 'Suez Cement Grey Portland CEM I 42.5 (50 kg)', 'cement', 'suez-cement', 'bag', 195, 20, 10, true, true, 92,
   'General-purpose Portland cement for concrete and masonry.', '{"Type":"CEM I 42.5N","Bag weight":"50 kg","Pallet":"40 bags"}'),
  ('arabian-cement-grey-bag', 'CM-ARB-G50', 'Arabian Cement Grey CEM II 42.5 (50 kg)', 'cement', 'arabian-cement', 'bag', 188, 20, 10, false, true, 80,
   'Blended Portland cement for plastering and masonry.', '{"Type":"CEM II/B-L 42.5N","Bag weight":"50 kg"}'),
  ('sinai-white-cement-bag', 'CM-SNW-W50', 'Sinai White Portland Cement (50 kg)', 'cement', 'sinai-white-cement', 'bag', 290, 10, 5, false, false, 50,
   'White cement for finishing, grout and decorative works.', '{"Type":"White CEM I 52.5","Bag weight":"50 kg"}'),
  ('suez-cement-grey-bulk', 'CM-SUZ-GT', 'Suez Cement Grey CEM I 42.5 (bulk, per ton)', 'cement', 'suez-cement', 'ton', 3850, 10, 1, false, false, 30,
   'Bulk cement delivered by tanker for ready-mix and large sites.', '{"Type":"CEM I 42.5N","Delivery":"Bulk tanker"}'),
  ('red-clay-brick', 'BR-RED-25', 'Red clay brick 25×12×6 cm', 'bricks-blocks', null, 'piece', 3.2, 1000, 500, false, true, 75,
   'Solid red clay brick for walls and partitions. Sold per piece, minimum 1,000.', '{"Size":"25 × 12 × 6 cm","Material":"Fired clay"}'),
  ('hollow-cement-block-20', 'BR-BLK-20', 'Hollow cement block 20×20×40 cm', 'bricks-blocks', null, 'piece', 14, 100, 50, false, false, 40,
   'Hollow concrete block for external walls and fences.', '{"Size":"20 × 20 × 40 cm","Material":"Concrete"}'),
  ('aac-block-10', 'BR-AAC-10', 'Lightweight AAC block 60×20×10 cm', 'bricks-blocks', null, 'piece', 38, 100, 50, true, false, 55,
   'Autoclaved aerated concrete block: light, insulating and fast to lay.', '{"Size":"60 × 20 × 10 cm","Density":"550 kg/m³"}'),
  ('washed-sand', 'SA-WSH', 'Washed building sand', 'sand-aggregates', null, 'm3', 330, 6, 1, false, true, 60,
   'Clean washed sand for concrete and plastering.', '{"Source":"Local quarry","Delivery":"Tipper truck"}'),
  ('crushed-gravel-1', 'SA-GRV-1', 'Crushed gravel (size 1)', 'sand-aggregates', null, 'm3', 520, 6, 1, false, false, 45,
   'Crushed dolomite aggregate for structural concrete.', '{"Size":"Size 1 (10–20 mm)","Material":"Dolomite"}'),
  ('yellow-fill-sand', 'SA-YLW', 'Yellow fill sand', 'sand-aggregates', null, 'm3', 220, 10, 1, false, false, 30,
   'Fill sand for leveling and backfilling.', '{"Use":"Backfill and leveling"}'),
  ('cleopatra-porcelain-60x60', 'TL-CLP-6060', 'Cleopatra porcelain floor tile 60×60 cm, matt grey', 'tiles-ceramics', 'cleopatra-ceramics', 'm2', 420, 10, 1, true, false, 65,
   'Rectified porcelain floor tile, matt finish.', '{"Size":"60 × 60 cm","Finish":"Matt","Grade":"First"}'),
  ('royal-wall-30x60', 'TL-RYL-3060', 'Royal Ceramica wall tile 30×60 cm, white gloss', 'tiles-ceramics', 'royal-ceramica', 'm2', 290, 10, 1, false, false, 40,
   'Glazed ceramic wall tile for kitchens and bathrooms.', '{"Size":"30 × 60 cm","Finish":"Gloss","Grade":"First"}'),
  ('cleopatra-floor-40x40', 'TL-CLP-4040', 'Cleopatra ceramic floor tile 40×40 cm, beige', 'tiles-ceramics', 'cleopatra-ceramics', 'm2', 240, 10, 1, false, false, 35,
   'Glazed ceramic floor tile.', '{"Size":"40 × 40 cm","Finish":"Satin","Grade":"First"}'),
  ('jotun-fenomastic-white-18l', 'PT-JTN-FEN18', 'Jotun Fenomastic Matt, white (18 L)', 'paints', 'jotun', 'piece', 2950, 1, 1, true, true, 70,
   'Washable interior emulsion with a smooth matt finish.', '{"Volume":"18 L","Finish":"Matt","Coverage":"10–12 m²/L"}'),
  ('sipes-plastic-7-18l', 'PT-SPS-P7', 'Sipes Plastic 7, white (18 L)', 'paints', 'sipes', 'piece', 1650, 1, 1, false, true, 60,
   'Interior plastic paint for walls and ceilings.', '{"Volume":"18 L","Finish":"Matt"}'),
  ('sipes-putty-15kg', 'PT-SPS-PTY', 'Sipes acrylic putty (15 kg)', 'paints', 'sipes', 'piece', 520, 1, 1, false, false, 40,
   'Ready-mixed acrylic putty for wall preparation.', '{"Weight":"15 kg","Use":"Interior"}'),
  ('banninger-ppr-25mm', 'PL-BNG-25', 'Bänninger PPR pipe 25 mm (4 m)', 'plumbing', 'banninger', 'piece', 310, 10, 1, false, false, 45,
   'PPR pressure pipe for hot and cold water.', '{"Diameter":"25 mm","Length":"4 m","Pressure":"PN20"}'),
  ('banninger-ppr-32mm', 'PL-BNG-32', 'Bänninger PPR pipe 32 mm (4 m)', 'plumbing', 'banninger', 'piece', 470, 10, 1, false, false, 30,
   'PPR pressure pipe for risers and main lines.', '{"Diameter":"32 mm","Length":"4 m","Pressure":"PN20"}'),
  ('elsewedy-cable-3mm', 'EL-SWD-3', 'Elsewedy single-core cable 3 mm² (100 m)', 'electrical', 'elsewedy-electric', 'roll', 2350, 1, 1, true, true, 72,
   'Copper single-core building wire.', '{"Section":"3 mm²","Length":"100 m","Conductor":"Copper"}'),
  ('elsewedy-cable-2mm', 'EL-SWD-2', 'Elsewedy single-core cable 2 mm² (100 m)', 'electrical', 'elsewedy-electric', 'roll', 1650, 1, 1, false, false, 55,
   'Copper single-core building wire for lighting circuits.', '{"Section":"2 mm²","Length":"100 m","Conductor":"Copper"}'),
  ('schneider-mcb-16a', 'EL-SCH-MCB16', 'Schneider Easy9 MCB 1P 16 A', 'electrical', 'schneider-electric', 'piece', 210, 5, 1, false, false, 40,
   'Miniature circuit breaker for final circuits.', '{"Poles":"1P","Rating":"16 A","Curve":"C"}'),
  ('schneider-db-12', 'EL-SCH-DB12', 'Schneider distribution board, 12 ways', 'electrical', 'schneider-electric', 'piece', 1450, 1, 1, false, false, 25,
   'Flush-mounted consumer unit.', '{"Ways":"12","Mounting":"Flush"}'),
  ('knauf-standard-board', 'GB-KNF-STD', 'Knauf standard gypsum board 12.5 mm (120×240)', 'gypsum-board', 'knauf', 'piece', 265, 10, 1, false, true, 50,
   'Standard plasterboard for ceilings and partitions.', '{"Thickness":"12.5 mm","Size":"120 × 240 cm"}'),
  ('knauf-moisture-board', 'GB-KNF-MR', 'Knauf moisture-resistant board 12.5 mm', 'gypsum-board', 'knauf', 'piece', 360, 10, 1, false, false, 30,
   'Green board for bathrooms and kitchens.', '{"Thickness":"12.5 mm","Size":"120 × 240 cm","Type":"Moisture resistant"}'),
  ('bitumen-membrane-4mm', 'IN-BIT-4', 'Bitumen waterproofing membrane 4 mm (10 m²)', 'insulation', null, 'roll', 1150, 5, 1, false, false, 35,
   'Torch-applied membrane for roofs and foundations.', '{"Thickness":"4 mm","Roll":"10 m²"}'),
  ('sika-topseal-107', 'IN-SKA-107', 'SikaTop Seal-107 waterproofing (25 kg)', 'insulation', 'sika', 'piece', 1350, 1, 1, false, false, 30,
   'Cementitious waterproofing for wet areas and water tanks.', '{"Pack":"25 kg","Use":"Bathrooms, tanks, basements"}'),
  ('xps-board-5cm', 'IN-XPS-5', 'XPS thermal insulation board 5 cm', 'insulation', null, 'm2', 260, 10, 1, false, false, 25,
   'Extruded polystyrene board for roof thermal insulation.', '{"Thickness":"5 cm","Density":"32 kg/m³"}')
)
insert into public.mat_products (slug, sku, name, category_id, brand_id, unit, base_price, min_order_qty, qty_step,
  is_featured, is_best_seller, popularity, description, specs, is_sample)
select p.slug, p.sku, p.name, c.id, b.id, p.unit, p.price, p.min_qty, p.step, p.featured, p.best, p.pop, p.descr, p.specs::jsonb, true
from p join public.mat_categories c on c.slug = p.cat left join public.mat_brands b on b.slug = p.brand;

-- per-area adjustments: steel by a fixed EGP/ton, everything else by a small percentage
with adj(slug, steel, pct) as (values
  ('cairo', 0, 0), ('new-cairo', 100, 2), ('new-capital', 250, 4), ('giza', 0, 0), ('october', 150, 2), ('sheikh-zayed', 150, 2))
insert into public.mat_product_area_prices (product_id, area_id, price_adjustment, stock_status)
select p.id, a.id,
  case when c.slug = 'steel-rebar' then adj.steel else round(p.base_price * adj.pct / 100, case when p.base_price < 50 then 1 else 0 end) end,
  case
    when p.slug = 'sinai-white-cement-bag' and a.slug = 'new-capital' then 'out_of_stock'
    when p.slug = 'aac-block-10' and a.slug in ('giza', 'cairo') then 'on_order'
    when p.slug in ('schneider-db-12', 'knauf-moisture-board') then 'low_stock'
    else 'in_stock' end
from public.mat_products p join public.mat_categories c on c.id = p.category_id
cross join public.mat_areas a join adj on adj.slug = a.slug;

-- daily price items: 5 steel makers x 6 sizes, plus grey/white cement
insert into public.mat_daily_price_items (kind, manufacturer, label, size_mm, unit, show_in_ticker, sort, is_sample, product_id)
select 'steel', m.name, 'Rebar ' || s.size || ' mm', s.size, 'ton', s.size = 16, m.sort * 10 + s.ord, true,
  (select id from public.mat_products where slug = m.slug_prefix || '-rebar-' || s.size || 'mm')
from (values ('Ezz Steel', 'ezz', 1), ('Beshay Steel', 'beshay', 2), ('Al Garhy Steel', 'al-garhy', 3),
             ('El Marakby Steel', 'el-marakby', 4), ('Suez Steel', 'suez-steel', 5)) m(name, slug_prefix, sort)
cross join (values (10, 1), (12, 2), (16, 3), (18, 4), (22, 5), (25, 6)) s(size, ord);

insert into public.mat_daily_price_items (kind, manufacturer, label, unit, show_in_ticker, sort, is_sample, product_id) values
  ('cement', 'Suez Cement',        'Grey cement CEM I 42.5',  'ton', true,  101, true, (select id from public.mat_products where slug = 'suez-cement-grey-bulk')),
  ('cement', 'Arabian Cement',     'Grey cement CEM II 42.5', 'ton', false, 102, true, null),
  ('cement', 'Sinai White Cement', 'White cement CEM I 52.5', 'ton', true,  103, true, null);

-- 30 days of SAMPLE history: one random walk per item, shifted per area
select setseed(0.42);
with base(manufacturer, kind, price) as (values
  ('Ezz Steel', 'steel', 39500), ('Beshay Steel', 'steel', 38900), ('Al Garhy Steel', 'steel', 38400),
  ('El Marakby Steel', 'steel', 38300), ('Suez Steel', 'steel', 38700),
  ('Suez Cement', 'cement', 3850), ('Arabian Cement', 'cement', 3750), ('Sinai White Cement', 'cement', 5800)),
adj(slug, steel, cement) as (values
  ('cairo', 0, 0), ('new-cairo', 100, 20), ('new-capital', 250, 40), ('giza', 0, 0), ('october', 150, 20), ('sheikh-zayed', 150, 20)),
days as (select generate_series(current_date - 29, current_date, interval '1 day')::date as d),
deltas as (
  select i.id as item_id, i.kind, i.size_mm, b.price, days.d,
    (random() - 0.47) * case when i.kind = 'steel' then 350 else 45 end as delta
  from public.mat_daily_price_items i join base b on b.manufacturer = i.manufacturer cross join days),
walk as (
  select item_id, kind, size_mm, price, d,
    sum(delta) over (partition by item_id order by d) - first_value(delta) over (partition by item_id order by d) as w
  from deltas)
insert into public.mat_price_history (item_id, area_id, price, recorded_on, recorded_at)
select w.item_id, a.id,
  case when w.kind = 'steel'
    then round((w.price + case w.size_mm when 10 then 300 when 12 then 150 else 0 end + adj.steel + w.w) / 50) * 50
    else round((w.price + adj.cement + w.w) / 10) * 10 end,
  w.d, w.d + time '10:00'
from walk w cross join public.mat_areas a join adj on adj.slug = a.slug;

insert into public.mat_banners (title, subtitle, link_url, cta_label, sort, is_sample) values
  ('Steel & cement prices, updated every morning', 'Compare Ezz, Beshay, Garhy, Marakby and Suez Steel for your area.', '/prices', 'See today''s prices', 1, true),
  ('Send your BOQ, get a price in hours', 'Upload an Excel, PDF or a photo of your list. We reply on WhatsApp.', '/quote', 'Request a quote', 2, true),
  ('Delivered to your site in Cairo & Giza', 'Order by the ton or by the bag, pay cash on delivery.', '/category/steel-rebar', 'Shop steel', 3, true);

-- admin access for the owner's emails (role is applied the first time they sign in)
insert into public.mat_staff_invites (email, role) values
  ('abdallahsad35@icloud.com', 'admin'), ('abdallahsad35@gmail.com', 'admin')
on conflict (email) do nothing;
