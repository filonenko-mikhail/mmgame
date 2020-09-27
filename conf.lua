local conf = {

   --- Replication user/password
   user = 'rep',
   password = 'pwd',

   -- Таблица для игры
   space_name = 'game',

   -- Структура таблицы
   format = {
       {name="id",     type="string"},
       {name="icon",   type="string"},
       {name="x",      type="unsigned"},
       {name="y",      type="unsigned"},
       {name="type",   type="string"},
       {name="health", type="unsigned"},
   },

   -- Ссылки на некоторые колонки
   id_field = 1,
   icon_field = 2,
   x_field = 3,
   y_field = 4,
   health_field = 6,

   -- Размер игрового поля
   width = 80,
   height = 40,

   -- Максимальная энергия от продукта
   max_energy = 5,

   -- Энергия при рождении
   born_health = 2,

   moon_type = 'moon',
   train_type = 'train',
   food_type = 'food',
   player_type = 'player',
   bomb_type = 'bomb',
   fire_type = 'fire',

   bomb_energy = 5,
   fire_energy = 2,

   moon_id = '1',
   train_id = '2',
}

return conf
