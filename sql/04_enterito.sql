-- Primera prenda real: Enterito corto negro
insert into categories (slug, name, image_url, sort_order)
values ('enteritos', 'Enteritos', '/media/enterito-negro.jpg', 0)
on conflict (slug) do nothing;

do $$
declare p uuid;
begin
  insert into products (slug,name,description,price,category_id,size_guide,is_new,is_featured,sort_order)
  values ('enterito-corto-negro','Enterito corto negro',
          'Enterito corto con tirantes de vuelo, escote cuadrado y botones forrados al frente. Cómodo, fresco y elegante.',
          9990,(select id from categories where slug='enteritos'),'superior',true,true,0)
  returning id into p;
  insert into product_media (product_id,kind,url,sort_order) values
    (p,'image','/media/enterito-negro.jpg',0),
    (p,'video','/media/enterito-negro.mp4',1);
  insert into product_variants (product_id,talla,color,stock,sort_order) values (p,'M/L','Negro',1,0);
end $$;
