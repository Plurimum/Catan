-- Регистрация пользователя
-- возвращает true, если регистрация прошла успешно, иначе - false
create or replace function registerUser(reg_username varchar(40), reg_password varchar(50))
    returns bool
    language plpgsql
as
$$
begin
    -- Юзернейм должен быть уникален
    -- Если уже существует пользователь с таким юзернеймом - регистрация неуспешна
    if (exists(select u.UserId
               from Users u
               where u.username = reg_username)) then
        return false;
    end if;

    insert into Users (username, password, nickname, rating)
    values (reg_username, reg_password, '', 0);

    return true;
end;
$$;

-- Проверка пользователя
-- возвращает true, если такой пользователь существует и его юзернейм и пароль совпали,
-- иначе - false
create or replace function checkUser(_username varchar(40), _password varchar(40))
    returns bool
    language plpgsql
as
$$
begin
    return exists(select u.UserId
                  from Users u
                  where u.username = _username
                    and u.password = _password);
end;
$$;

-- Изменение никнейма
-- возвращает true, если смена никнейма прошла успешно, иначе - false
create or replace function changeNickname(_username varchar(40), _password varchar(50), new_nickname varchar(40))
    returns bool
    language plpgsql
as
$$
begin
    if (
            _username is null or
            _password is null or
            new_nickname is null or
            not checkUser(_username, _password)
        ) then
        return false;
    end if;

    update Users u
    set Nickname = new_nickname
    where u.username = _username
      and u.password = _password;

    return true;
end;
$$;

-- генерирует случайную перестановку игровых клеток
create or replace function getRandomBoard()
    returns resource_type_t[]
    language plpgsql
as
$$
declare
    result resource_type_t[];
begin
    select array_agg(elem order by random())
    into result
    from unnest(array [
        'wood', 'wood', 'wood', 'wood',
        'clay', 'clay', 'clay', 'clay',
        'wool', 'wool', 'wool', 'wool',
        'grain', 'grain', 'grain', 'grain',
        'ore', 'ore', 'ore'
        ]) elem;
    return result;
end ;
$$;

-- генерирует случайное число по указанному отрезку
create or replace function getRandomBetween(low integer, high integer)
    returns int
    language plpgsql
as
$$
begin
    return floor(random() * (high - low + 1) + low);
end;
$$;

-- Старт новой партии. Принимать участие в играх
-- могут только зарегистрированные пользователи.
-- Возвращает GameId созданной игры. Если игру создать не удалось, возвращает -1.
create or replace function startGame(_username varchar(40), _password varchar(50))
    returns integer
    language plpgsql
as
$$
declare
    lastCreatedPlayer int;
    game_id           int;
    board             resource_type_t[];
    cell_type         resource_type_t;
    pos               int;
begin
    -- проверяем аккаунт пользователя
    if (not checkUser(_username, _password)) then
        return -1;
    end if;

    -- получаем последнего созданного игрока
    select PlayerId
    into lastCreatedPlayer
    from Players
    order by PlayerId desc
    limit 1;

    -- добавляем новую партию
    insert into Games (StartTime, EndTime, WinningPlayerId)
    values (now(), null, lastCreatedPlayer + 1);

    -- получаем идентификатор новой партии
    select g.GameId
    into game_id
    from Games g
    where g.WinningPlayerId = lastCreatedPlayer + 1;

    -- добавляем игрока, начавшего партию
    -- указываем выигрывающим на данный момент игроком, так как других
    -- игроков в партии еще нет
    insert into Players (UserId, GameId, Score)
        (select u.UserId, game_id, 0
         from Users u
         where u.UserName = _username);

    -- создадим случайное игровое поле для этой партии
    board = getRandomBoard();
    pos := 1;
    foreach cell_type in array board
        loop
            insert into Cells (GameId, CellType, NumberForMining, Position)
            values (game_id, cell_type, getRandomBetween(2, 12), pos);

            pos := pos + 1;
        end loop;

    return game_id;
end;
$$;

-- Проверка пользователя и наличия указанной активной игры
create or replace function checkUserAndGame(_username varchar(40), _password varchar(50), _game_id int)
    returns bool
    language plpgsql
as
$$
begin
    return checkUser(_username, _password) and
           exists(select GameId
                  from ActiveGames active_games
                  where active_games.GameId = _game_id);
end;
$$;

-- Подключение пользователя к существующей игре.
-- Возвращает true, если успешно удалось подключиться, иначе - false
create or replace function joinGame(_username varchar(40), _password varchar(50), _game_id int)
    returns bool
    language plpgsql
as
$$
begin
    -- проверяем аккаунт пользователя и наличие такой активной игры
    if (not checkUserAndGame(_username, _password, _game_id)) then
        return false;
    end if;

    insert into Players (UserId, GameId, Score)
        (select u.UserId, _game_id, 0
         from Users u
         where u.Username = _username);

    return true;
end;
$$;

-- Возвращает активного игрока по юзернейму пользователя и указанной партии
create or replace function getActivePlayer(_username varchar(40), _game_id integer)
    returns integer
    language plpgsql
as
$$
declare
    player_id integer;
begin
    select active_players.PlayerId
    into player_id
    from playersInActiveGame(_game_id) active_players
    where active_players.Username = _username;

    return player_id;
end;
$$;

-- Выполнение начала хода.
-- Начало хода представляет из себя:
-- бросок нечестных кубиков, по значению на них игроки получают ресурсы,
-- в соответствии с ячейками, на которых у них есть постройки.
-- Возвращает true, если начало хода успешно выполнена
create or replace function makeStartOfMove(_username varchar(40), _password varchar(50), _game_id integer)
    returns bool
    language plpgsql
as
$$
declare
    dices_value integer := getRandomBetween(2, 12);
    player_id   integer;
begin
    -- проверяем аккаунт пользователя и наличие такой активной игры
    if (not checkUserAndGame(_username, _password, _game_id)) then
        return false;
    end if;

    -- Получаем игрока, который делает ход
    player_id := getActivePlayer(_username, _game_id);

    -- Добавляем ход
    insert into Moves (PlayerId, GameId, DicesValue)
    values (player_id, _game_id, dices_value);

    -- Выдадим игрокам ресурсы
    update Resources r
    set Count = r.Count + income.Count
    from Income income
    where NumberForMining = dices_value
      and income.GameId = _game_id
      and r.PlayerId = income.PlayerId
      and r.ResourceType = income.CellType;

    return true;
end;
$$;

select * from Moves;

create or replace procedure startTurn(player_id integer, game_id integer)
    language plpgsql
as
$$
declare
    dices_value integer = floor(random() * 6 + 1) + floor(random() * 6 + 1);
begin
    -- Добавляем ход
    insert into Moves (PlayerId, GameId, DicesValue)
    values (player_id, game_id, dices_value);

    -- Выдадим игрокам ресурсы
    update Resources r
    set Count = r.Count + income.Count
    from Income income
    where NumberForMining = dices_value
      and income.GameId = game_id
      and r.PlayerId = income.PlayerId
      and r.ResourceType = income.CellType;
end;
$$;

call startTurn(2, 2);

select * from Resources;

-- D
create or replace function upgradeSettlementToCity(_username varchar(40), _password varchar(50), _game_id integer,
                                                   _position integer)
    returns bool
    language plpgsql
as
$$
declare
    player_id integer;
begin
    -- проверяем аккаунт пользователя и наличие такой активной игры
    if (not checkUserAndGame(_username, _password, _game_id)) then
        return false;
    end if;

    -- Получаем игрока, который делает ход
    player_id := getActivePlayer(_username, _game_id);

    -- Проверяем, что постройка 'settlement' существует на указанной позиции,
    -- а также принадлежит данному игроку
    if (not exists(select b.BuildingId
                   from (Buildings
                       natural join Moves
                       natural join Players) b
                   where b.Position = _position
                     and b.BuildingType = 'settlement'
                     and b.PlayerId = player_id)
        ) then
        return false;
    end if;

    -- Улучшаем постройку
    update Buildings b
    set BuildingType = 'city'
    where b.Position = _position;

    return true;
end;
$$;