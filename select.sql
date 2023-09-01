-- получение таблицы лидеров по рейтингу
create or replace function leaderboard()
    returns table
            (
                UserId   integer,
                Nickname varchar(40),
                Rating   integer
            )
    language plpgsql
as
$$
begin
    return query select u.UserId, u.Nickname, u.Rating
                 from Users u
                 order by u.Rating desc;
end;
$$;

-- получение списка оконченных игр и игроков с их набранными очками
create or replace function gamesList()
    returns table
            (
                GameId   integer,
                UserId   integer,
                Nickname varchar(40),
                Score    integer
            )
    language plpgsql
as
$$
begin
    return query select finished.GameId, finished.UserId, finished.Nickname, finished.Score
                 from FinishedGamesPlayers finished;
end;
$$;

-- получение списка игр и их победителей
create or replace function winnersList()
    returns table
            (
                GameId   integer,
                UserId   integer,
                Nickname varchar(40)
            )
    language plpgsql
as
$$
begin
    return query select finished.GameId, finished.UserId, finished.Nickname
                 from FinishedGamesPlayers finished
                 where finished.WinningPlayerId = finished.PlayerId;
end;
$$;

-- получение игрового поля в активной игре
create or replace function getBoard(active_game_id integer)
    returns table
            (
                CellType        resource_type_t,
                NumberForMining integer,
                PositionOnBoard integer
            )
    language plpgsql
as
$$
begin
    return query select active_games.CellType, active_games.NumberForMining, active_games.Position
                 from (ActiveGames
                     natural join Cells) active_games
                 where active_games.GameId = active_game_id;
end;
$$;

-- получение списка ресурсов игрока в указанной активной игре
-- например, игрок хочет видеть какие у него есть ресурсы на руках
create or replace function getHand(user_id integer, active_game_id integer)
    returns table
            (
                ResourceType resource_type_t,
                Count        integer
            )
    language plpgsql
as
$$
begin
    return query select h.ResourceType, h.Count
                 from Hands h
                 where h.UserId = user_id
                   and h.GameId = active_game_id;
end;
$$;

-- получение игроков, участвующих/участвовавших в игре (активной или завершенной)
create or replace function playersInGame(game integer)
    returns table
            (
                UserId   integer,
                Nickname varchar(40)
            )
    language plpgsql
as
$$
begin
    return query select lobby.UserId, lobby.Nickname
                 from (Games
                     natural join Players
                     natural join Users) lobby
                 where lobby.GameId = game;
end;
$$;

-- получение игроков активной игры
create or replace function playersInActiveGame(_game_id integer)
    returns table
            (
                UserId   integer,
                PlayerId integer,
                Username varchar(40)
            )
    language plpgsql
as
$$
begin
    return query select active_players.UserId, active_players.PlayerId, active_players.UserName
                 from ActivePlayers active_players
                 where active_players.GameId = _game_id;
end;
$$;

-- Получение таблицы, по которой можно определить какие игроки, за какие постройки,
-- какие ресурсы зарабатывают, при выпадении определенного числа на кубиках.
create or replace function miningBuildings(game integer)
    returns table
            (
                PlayerId        integer,
                BuildingType    build_type_t,
                NumberForMining integer,
                CellType        resource_type_t
            )
    language plpgsql
as
$$
begin
    return query select m.PlayerId, m.BuildingType, m.NumberForMining, m.CellType
                 from MiningBuildings m
                 where m.GameId = game;
end;
$$;

-- получение текущих построек всех игроков в указанной активной игре
create or replace function buildingsInGame(game integer)
    returns table
            (
                UserId          integer,
                BuildingType    build_type_t,
                PositionOnBoard integer
            )
    language plpgsql
as
$$
begin
    return query select active.UserId, active.BuildingType, active.Position
                 from ActiveBuildings active
                 where active.GameId = game;
end;
$$;

-- получение текущих построек игрока в указанной активной игре
create or replace function playerBuildingsInGame(user_id integer, game integer)
    returns table
            (
                BuildingType    build_type_t,
                PositionOnBoard integer
            )
    language plpgsql
as
$$
begin
    return query select active.BuildingType, active.PositionOnBoard
                 from buildingsInGame(game) active
                 where active.UserId = user_id;
end;
$$;

-- получение текущих карт развития у игроков в указанной активной игре
create or replace function cardsInGame(game integer)
    returns table
            (
                UserId   integer,
                CardType card_type_t
            )
    language plpgsql
as
$$
begin
    return query select cards.UserId, cards.CardType
                 from ActiveDevelopmentCards cards
                 where cards.GameId = game;
end;
$$;

-- получение текущих карт развития у игрока в указанной активной игре
create or replace function playerCardsInGame(user_id integer, game integer)
    returns table
            (
                CardType card_type_t
            )
    language plpgsql
as
$$
begin
    return query select cards.CardType
                 from cardsInGame(game) cards
                 where cards.UserId = user_id;
end;
$$;