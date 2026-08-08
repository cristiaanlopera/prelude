-- PRELUDE STUDIO · FASE 5
-- Recompensas + Museo Olfativo administrables desde Studio.

create table if not exists public.prelude_reward_settings (
  id text primary key, threshold integer not null check(threshold>0), reward_label text not null, active boolean not null default true, sort_order integer not null default 0, updated_at timestamptz not null default now()
);
alter table public.prelude_reward_settings enable row level security;

-- La web pública NO accede directamente a la tabla; usa RPCs SECURITY DEFINER.
-- Bloqueamos acceso directo por defecto.
drop policy if exists prelude_reward_settings_no_direct_access on public.prelude_reward_settings;
create policy prelude_reward_settings_no_direct_access
on public.prelude_reward_settings
for all
to public
using (false)
with check (false);

insert into public.prelude_reward_settings(id,threshold,reward_label,active,sort_order) values
('reward-30',30,'Descubrimiento Prelude de 2 ml sorpresa',true,10),
('reward-75',75,'Descubrimiento Prelude de 2 ml entre 3 opciones',true,20),
('reward-150',150,'Descubrimiento Signature de 5 ml',true,30),
('reward-250',250,'Recompensa exclusiva Prelude',true,40)
on conflict(id) do nothing;

create table if not exists public.prelude_museum_works (
 perfume_name text primary key, brand text not null default '', artwork_path text not null default '', description text not null default '', published boolean not null default true, updated_at timestamptz not null default now()
);
alter table public.prelude_museum_works enable row level security;

-- Igual que recompensas: lectura pública y administración solo mediante RPCs.
drop policy if exists prelude_museum_works_no_direct_access on public.prelude_museum_works;
create policy prelude_museum_works_no_direct_access
on public.prelude_museum_works
for all
to public
using (false)
with check (false);

insert into public.prelude_museum_works(perfume_name,brand,artwork_path,description,published) values
('Le Sel d''Issey','Issey Miyake','assets/artworks/le-sel-d-issey.webp','El hombre avanza solo por un espigón todavía húmedo después del temporal. La obra convierte la sal, el viento y la piedra mojada en una imagen de silencio y pureza: no representa el mar como destino, sino como un lugar interior donde respirar.',true),
('Amber Oud Gold Edition','Al Haramain','assets/artworks/amber-oud-gold-edition.webp','Una tarde cálida en una finca mediterránea concentra fruta madura, vegetación y luz dorada. La escena interpreta la exuberancia dulce y sensual de la fragancia como un verano llevado hasta su punto más pleno, donde todo parece haber absorbido el sol.',true),
('Dior Homme Intense','Dior','assets/artworks/dior-homme-intense.webp','La elegancia aparece como un ritual íntimo y silencioso. El protagonista, rodeado de luz tenue y materiales nobles, representa una sofisticación profunda que no busca llamar la atención: la misma presencia refinada, empolvada y amaderada que deja la fragancia.',true),
('Mercedes-Benz Club Black','Mercedes-Benz','assets/artworks/mercedes-benz-club-black.webp','Fuera domina la nieve y el azul de la noche; dentro, la madera y el fuego convierten el espacio en refugio. La obra traduce la vainilla, el ámbar y las resinas en sensación térmica: una oscuridad cálida, masculina y envolvente.',true),
('CK One','Calvin Klein','assets/artworks/ck-one.webp','Una lavandería de los años noventa convierte lo cotidiano en libertad. Camiseta blanca, denim, amigos y luz limpia expresan el carácter cítrico, verde y despreocupado de CK One: juventud sin pose, vivida en presente.',true),
('La Nuit de L''Homme','Yves Saint Laurent','assets/artworks/la-nuit-de-l-homme.webp','Un hombre elegante permanece bajo una marquesina cuando la lluvia acaba de cesar. Las luces reflejadas y la espera indefinida convierten la noche en posibilidad: misterio, atracción y la sensación de que algo importante está a punto de suceder.',true),
('Club de Nuit Sillage','Armaf','assets/artworks/club-de-nuit-sillage.webp','El agua del deshielo atraviesa un valle alpino y el protagonista se refresca con ella. La escena convierte la frescura metálica, cítrica y almizclada en algo físico: agua helada, aire blanco y una estela limpia que continúa su camino entre las montañas.',true),
('Détour Noir','Al Haramain','assets/artworks/detour-noir.webp','Un hombre y un caballo atraviesan una finca ecuestre al comienzo de una mañana fría. La neblina, el cuero, la madera y la luz cálida representan la dualidad de la fragancia: frescor especiado en el aire y una base dulce, cremosa y distinguida.',true),
('Fico di Amalfi','Acqua di Parma','assets/artworks/fico-di-amalfi.webp','Una mañana lenta en la Costa Amalfitana: lino, piedra clara, hojas de higuera y una vista parcial del Mediterráneo. La obra interpreta la fragancia como el placer sencillo de un verano italiano, luminoso, cítrico y relajado.',true),
('Eros','Versace','assets/artworks/eros.webp','Una noche mediterránea transforma la atracción en narrativa. Entre arquitectura clásica, agua turquesa y luz dorada, el protagonista avanza hacia aquello que desea; la obra une frescura, juventud y sensualidad con la seguridad impulsiva que define Eros.',true),
('Bois Impérial','Essential Parfums','assets/artworks/bois-imperial.webp','Arquitectura contemporánea y vegetación húmeda se mezclan hasta resultar inseparables. La obra representa el contraste esencial de Bois Impérial: precisión mineral y moderna frente a una naturaleza verde, especiada y amaderada que vuelve a ocupar el espacio.',true),
('Bal d''Afrique','Byredo','assets/artworks/byredo-afrique.webp','Un patio lleno de música, conversación y movimiento convierte la fragancia en una celebración cultural y luminosa. La obra no representa un lugar exótico, sino el instante en que el viajero deja de sentirse visitante y entra en el ritmo de la escena.',true),
('Le Rem','Réminiscence','assets/artworks/le-rem.webp','El protagonista vuelve al mar como quien vuelve a un recuerdo. La sal, la luz mediterránea y la distancia del horizonte convierten la escena en nostalgia serena: no es simplemente el mar, sino la memoria de algo que nunca terminó de marcharse.',true),
('Le Beau','Jean Paul Gaultier','assets/artworks/le-beau.webp','Palmeras, lino, bañador, cócteles tropicales y una tarde que parece no tener final. La obra interpreta Le Beau como unas vacaciones juveniles vividas sin preocupación: coco, calor, diversión y la libertad del mejor verano de tu vida.',true),
('Stronger With You','Giorgio Armani','assets/artworks/stronger-with-you.webp','El protagonista conduce a alguien hacia un salón iluminado por la chimenea, aunque esa persona apenas aparece. El gesto de la mano convierte la calidez en vínculo: la obra habla de intimidad, hogar y de cómo un lugar adquiere sentido cuando se comparte.',true),
('Torino 21','Xerjoff','assets/artworks/torino-21.webp','Una mañana impecable en un club de tenis histórico transmite energía antes que competición. El césped húmedo, la ropa clara y el aire fresco traducen la menta, los cítricos y las hierbas aromáticas en una elegancia deportiva, limpia y vital.',true),
('First Instinct','Abercrombie & Fitch','assets/artworks/first-instinct.webp','Una terraza mediterránea al final de la tarde captura el instante anterior a una historia. El gin-tonic, el melón servido de forma natural y la mirada del protagonista convierten la frescura frutal del perfume en espontaneidad, juventud y primer impulso.',true),
('Egeo Bomb Black','O Boticário','assets/artworks/egeo-bomb-black.webp','Una feria nocturna casi vacía conserva todavía el brillo de sus luces sobre el suelo mojado. El cuero oscuro del protagonista y la dulzura de los puestos convierten caramelo y vainilla en una noche juvenil, adictiva y ligeramente rebelde que se resiste a terminar.',true),
('Armani Code','Giorgio Armani','assets/artworks/armani-code.webp','Un hombre solo atraviesa la ciudad con una elegancia absolutamente contenida. La arquitectura, la noche y sus pequeños rituales de precisión representan la personalidad de Code: sofisticación italiana, misterio y control sin necesidad de exhibición.',true),
('Starwalker','Montblanc','assets/artworks/starwalker.webp','Una biblioteca luminosa se abre hacia un jardín mediterráneo y un horizonte por descubrir. Mapas, madera y vegetación forman un espacio coherente donde la curiosidad es protagonista: Starwalker aparece como el impulso de mirar más allá y seguir explorando.',true),
('Nautica Voyage','Nautica','assets/artworks/nautica-voyage.webp','Un hombre navega solo en mar abierto, lejos de cualquier costa. El espacio vacío, la vela y el horizonte convierten el acorde acuático y verde en serenidad: la libertad no está en llegar a un destino, sino en elegir estar lejos de todo por un momento.',true),
('Cool Water','Davidoff','assets/artworks/cool-water.webp','El protagonista acaba de salir del mar y asciende por la roca todavía mojado. La escena hace física la fragancia: agua fría sobre la piel, viento, piedra y vegetación; una sensación de energía limpia y libertad que despierta todo el cuerpo.',true),
('Sauvage','Dior','assets/artworks/sauvage.webp','Después de una tormenta, un hombre permanece pequeño frente a una extensión árida inmensa. El aire limpio, la roca húmeda y el horizonte abierto traducen el frescor especiado y mineral de Sauvage en una idea elemental: libertad porque no hay nada alrededor.',true)
on conflict(perfume_name) do update set brand=excluded.brand where public.prelude_museum_works.brand='';

create or replace function public.admin_list_prelude_reward_settings() returns jsonb language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if; return coalesce((select jsonb_agg(to_jsonb(r) order by r.sort_order,r.threshold) from public.prelude_reward_settings r),'[]'::jsonb); end; $$;
create or replace function public.admin_save_prelude_reward_setting(input_id text,input_threshold integer,input_reward_label text,input_active boolean,input_sort_order integer) returns jsonb language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if; update public.prelude_reward_settings set threshold=input_threshold,reward_label=trim(input_reward_label),active=coalesce(input_active,true),sort_order=coalesce(input_sort_order,0),updated_at=now() where id=input_id; return jsonb_build_object('success',found); end; $$;
create or replace function public.get_prelude_reward_settings() returns jsonb language sql security definer set search_path=public as $$ select coalesce(jsonb_agg(jsonb_build_object('id',id,'threshold',threshold,'reward_label',reward_label,'active',active,'sort_order',sort_order) order by sort_order,threshold),'[]'::jsonb) from public.prelude_reward_settings where active=true; $$;

create or replace function public.admin_list_prelude_museum_works() returns jsonb language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if; return coalesce((select jsonb_agg(to_jsonb(m) order by m.perfume_name) from public.prelude_museum_works m),'[]'::jsonb); end; $$;
create or replace function public.admin_save_prelude_museum_work(input_perfume_name text,input_artwork_path text,input_description text,input_published boolean) returns jsonb language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if; update public.prelude_museum_works set artwork_path=trim(input_artwork_path),description=trim(input_description),published=coalesce(input_published,true),updated_at=now() where perfume_name=input_perfume_name; return jsonb_build_object('success',found); end; $$;
create or replace function public.get_prelude_museum_works() returns jsonb language sql security definer set search_path=public as $$ select coalesce(jsonb_agg(jsonb_build_object('perfume_name',perfume_name,'brand',brand,'artwork_path',artwork_path,'description',description,'published',published) order by perfume_name),'[]'::jsonb) from public.prelude_museum_works where published=true; $$;

revoke all on function public.admin_list_prelude_reward_settings() from public; grant execute on function public.admin_list_prelude_reward_settings() to authenticated;
revoke all on function public.admin_save_prelude_reward_setting(text,integer,text,boolean,integer) from public; grant execute on function public.admin_save_prelude_reward_setting(text,integer,text,boolean,integer) to authenticated;
grant execute on function public.get_prelude_reward_settings() to anon,authenticated;
revoke all on function public.admin_list_prelude_museum_works() from public; grant execute on function public.admin_list_prelude_museum_works() to authenticated;
revoke all on function public.admin_save_prelude_museum_work(text,text,text,boolean) from public; grant execute on function public.admin_save_prelude_museum_work(text,text,text,boolean) to authenticated;
grant execute on function public.get_prelude_museum_works() to anon,authenticated;


-- Seguridad adicional: sin acceso directo a tablas desde anon/authenticated.
revoke all on table public.prelude_reward_settings from anon, authenticated;
revoke all on table public.prelude_museum_works from anon, authenticated;

-- Los usuarios públicos solo ejecutan RPCs de lectura.
grant execute on function public.get_prelude_reward_settings() to anon, authenticated;
grant execute on function public.get_prelude_museum_works() to anon, authenticated;

-- Las RPC administrativas solo son invocables por sesiones authenticated
-- y además verifican pertenencia a public.prelude_admins.
