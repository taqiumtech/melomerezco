-- ══════════════════════════════════════════════════════════════
-- Prendas de PRUEBA para ver el diseño. Se pueden borrar después
-- con el bloque del final (o desde el panel /admin).
-- ══════════════════════════════════════════════════════════════
do $$
declare
  c_pal uuid := (select id from categories where slug='palazzos');
  c_jea uuid := (select id from categories where slug='jeans');
  c_bod uuid := (select id from categories where slug='bodys');
  c_top uuid := (select id from categories where slug='tops');
  c_ves uuid := (select id from categories where slug='vestidos');
  c_fal uuid := (select id from categories where slug='faldas');
  p uuid;
begin
  -- 1 Palazzo
  insert into products (slug,name,description,measures,price,compare_price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('demo-palazzo-azul','Palazzo azul tiro alto','Palazzo de tiro alto con caída fluida y bolsillos laterales. Cómodo para la oficina o una salida con amigas.','Largo 104 cm · Tiro 31 cm · La modelo usa talla 38',19990,24990,c_pal,'inferior',true,true,1) returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values (p,'image','/assets/cat-palazzos.jpg',0),(p,'image','/assets/det-palazzos.jpg',1);
  insert into product_variants (product_id,talla,stock,sort_order) values (p,'36',2,0),(p,'38',5,1),(p,'40',4,2),(p,'42',1,3),(p,'44',0,4);

  -- 2 Jeans (con video)
  insert into products (slug,name,description,measures,price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('demo-jeans-mom','Jeans mom rasgado','Jeans mom fit tiro alto con roturas y basta doblada. Denim con un toque de elasticidad.','Largo 98 cm · Tiro 29 cm',22990,c_jea,'inferior',true,true,2) returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values (p,'image','/assets/cat-jeans.jpg',0),(p,'video','/assets/demo-jeans.mp4',1),(p,'image','/assets/det-jeans.jpg',2);
  insert into product_variants (product_id,talla,stock,sort_order) values (p,'36',3,0),(p,'38',6,1),(p,'40',6,2),(p,'42',2,3);

  -- 3 Body (con colores)
  insert into products (slug,name,description,price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('demo-body-manga-larga','Body manga larga escote V','Body de tela suave con elasticidad y broche inferior. Combínalo con falda, jeans o palazzo.',14990,c_bod,'superior',true,false,3) returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values (p,'image','/assets/cat-bodys.jpg',0),(p,'image','/assets/det-bodys.jpg',1);
  insert into product_variants (product_id,talla,color,stock,sort_order) values
    (p,'S','Negro',4,0),(p,'M','Negro',3,1),(p,'L','Negro',0,2),
    (p,'S','Fucsia',2,3),(p,'M','Fucsia',5,4),(p,'L','Fucsia',1,5);

  -- 4 Top crop (con video)
  insert into products (slug,name,description,price,compare_price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('demo-top-crop-floral','Top crop floral','Top crop con mangas abullonadas y estampado de flores. El favorito del verano.',12990,15990,c_top,'superior',true,true,4) returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values (p,'image','/assets/cat-tops.jpg',0),(p,'video','/assets/demo-tops.mp4',1),(p,'image','/assets/det-tops.jpg',2);
  insert into product_variants (product_id,talla,stock,sort_order) values (p,'S',2,0),(p,'M',4,1),(p,'L',3,2),(p,'XL',1,3);

  -- 5 Palazzo beige
  insert into products (slug,name,description,price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('demo-palazzo-beige','Palazzo lino beige','Palazzo de lino, fresco y liviano, con pretina elástica.',21990,c_pal,'inferior',true,false,5) returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values (p,'image','/assets/det-tops.jpg',0),(p,'image','/assets/cat-tops.jpg',1);
  insert into product_variants (product_id,talla,stock,sort_order) values (p,'S',3,0),(p,'M',3,1),(p,'L',2,2);

  -- 6 Falda (talla única)
  insert into products (slug,name,description,price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('demo-falda-tweed','Falda cruzada tweed','Falda corta cruzada de tweed, ideal con body o top.',16990,c_fal,'unica',true,false,6) returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values (p,'image','/assets/det-bodys.jpg',0);
  insert into product_variants (product_id,talla,stock,sort_order) values (p,'Única',6,0);

  -- 7 Vestido AGOTADO (para ver cómo se muestra)
  insert into products (slug,name,description,price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('demo-vestido-rosa','Vestido midi rosa','Vestido midi con vuelo. ¡Vuelve pronto!',27990,c_ves,'superior',false,false,7) returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values (p,'image','/assets/promo.jpg',0);
  insert into product_variants (product_id,talla,stock,sort_order) values (p,'S',0,0),(p,'M',0,1),(p,'L',0,2);
end $$;

-- Para BORRAR las prendas de prueba:
-- delete from products where slug like 'demo-%';
