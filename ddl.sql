drop table if exists Users cascade;

-- Здесь хранятся данные о пользователях
create table Users
(
    UserId   serial primary key,
    UserName varchar(40) unique not null,
    Password varchar(50)        not null,
    Nickname varchar(40)        not null,
    Rating   integer            not null
);

drop table if exists Games cascade;

create table Games
(
    GameId          serial primary key,
    StartTime       timestamp not null,
    EndTime         timestamp,
    WinningPlayerId integer   not null
);

drop table if exists Players cascade;

create table Players
(
    PlayerId serial primary key,
    UserId   integer not null,
    GameId   integer not null,
    Score    integer not null,

    constraint user_fk foreign key (UserId) references Users (UserId) on delete cascade,
    constraint game_fk foreign key (GameId) references Games (GameId) on delete cascade
);

drop type if exists resource_type_t cascade;
create type resource_type_t as enum ('wood', 'clay', 'wool', 'grain', 'ore');

drop table if exists Cells cascade;

create table Cells
(
    CellId          serial primary key,
    GameId          integer         not null,
    CellType        resource_type_t not null,
    NumberForMining integer         not null,
    Position        integer         not null,

    constraint game_fk foreign key (GameId) references Games (GameId) on delete cascade
);

drop table if exists Resources cascade;

create table Resources
(
    ResourceId   integer         not null,
    PlayerId     integer         not null,
    ResourceType resource_type_t not null,
    Count        integer         not null,

    constraint resource_pk primary key (ResourceId),
    constraint player_fk foreign key (PlayerId) references Players (PlayerId) on delete cascade
);

drop table if exists Moves cascade;

create table Moves
(
    MoveId     serial primary key,
    PlayerId   integer not null,
    GameId     integer not null,
    DicesValue integer not null,

    constraint player_fk foreign key (PlayerId) references Players (PlayerId) on delete cascade,
    constraint game_fk foreign key (GameId) references Games (GameId) on delete cascade
);

drop table if exists ResourceExchanges cascade;

create table ResourceExchanges
(
    ExchangeId   integer         not null,
    MoveId       integer         not null,
    WithPlayerId integer         not null,
    Resource     resource_type_t not null,
    Count        integer         not null,

    constraint exchange_pk primary key (ExchangeId),
    constraint move_fk foreign key (MoveId) references Moves (MoveId) on delete cascade
);

drop type if exists build_type_t cascade;
create type build_type_t as enum ('road', 'settlement', 'city');

drop table if exists Buildings cascade;

create table Buildings
(
    BuildingId   integer      not null,
    MoveId       integer      not null,
    BuildingType build_type_t not null,
    Position     integer      not null,

    constraint building_pk primary key (BuildingId),
    constraint move_fk foreign key (MoveId) references Moves (MoveId) on delete cascade
);

drop type if exists card_type_t cascade;
create type card_type_t as enum ('knight', 'monopoly', 'road_building', 'year_of_abundance', 'winning_point');

drop table if exists DevelopmentCards cascade;

create table DevelopmentCards
(
    CardId   integer     not null,
    MoveId   integer     not null,
    CardType card_type_t not null,

    constraint card_pk primary key (CardId),
    constraint move_fk foreign key (MoveId) references Moves (MoveId) on delete cascade
);

-- Оконченные игры
create or replace view FinishedGames
as
select GameId, StartTime, EndTime, WinningPlayerId
from Games
where EndTime is not null;

-- Участники оконченных игр
create or replace view FinishedGamesPlayers
as
select fgp.GameId, fgp.UserId, fgp.PlayerId, fgp.Nickname, fgp.WinningPlayerId, fgp.Score
from (FinishedGames
    natural join Players
    natural join Users) fgp;

-- Активные (еще не оконченные) игры
create or replace view ActiveGames
as
select GameId, StartTime
from Games
where EndTime is null;

-- Игроки, находящиеся в активных (еще не оконченных) играх
create or replace view ActivePlayers
as
select active_players.GameId,
       active_players.UserId,
       active_players.PlayerId,
       active_players.UserName,
       active_players.Nickname,
       active_players.Score
from (ActiveGames
    natural join Players
    natural join Users) active_players;

-- Ресурсы на руках игроков в активных (еще не оконченных) играх
create or replace view Hands
as
select hand.GameId, hand.UserId, hand.Nickname, hand.ResourceType, hand.Count
from (Resources
    natural join ActivePlayers) hand;

-- Ходы игроков в активных (еще не оконченных играх)
create or replace view ActiveMoves
as
select active_moves.GameId,
       active_moves.PlayerId,
       active_moves.UserId,
       active_moves.Nickname,
       active_moves.MoveId,
       active_moves.DicesValue
from (ActivePlayers
    natural join Moves) active_moves;

-- Постройки игроков в активных (еще не оконченных) играх
create or replace view ActiveBuildings
as
select active_buildings.GameId,
       active_buildings.UserId,
       active_buildings.PlayerId,
       active_buildings.Nickname,
       active_buildings.BuildingId,
       active_buildings.BuildingType,
       active_buildings.Position
from (ActiveMoves
    natural join Buildings) active_buildings;

-- Вью, по которой определяется какие игроки, за какие постройки,
-- какие ресурсы зарабатывают, при выпадении определенного числа на кубиках.
-- То есть например запись:
-- {1, 1, 'settlement', 8, 'clay'}
-- означает, что в партии 1, игрок 1 может получать ресурс 'clay' за свою
-- постройку 'settlement', если на выпавшая сумма на кубиках равна 8.
create or replace view MiningBuildings
as
select a.GameId, a.PlayerId, a.BuildingType, c.NumberForMining, c.CellType
from ActiveBuildings a
         join Cells c on a.GameId = c.GameId
where (a.Position = c.Position * 2 or
       a.Position = c.Position * 2 - 1)
  and (a.BuildingType = 'settlement' or
       a.BuildingType = 'city');

-- Вью прибыли. По ней можно определить сколько каких ресурсов
-- зарабатывают игроки, при выпадении определенного числа на кубиках.
create or replace view Income
as
select m.GameId, m.PlayerId, m.CellType, m.NumberForMining, m.Count
from Resources r
         join (select GameId, PlayerId, CellType, NumberForMining, count(BuildingType)
               from MiningBuildings
               group by GameId, PlayerId, CellType, NumberForMining) m on r.Playerid = m.PlayerId
where m.CellType = r.ResourceType;

-- Карты развития у игроков в активных (еще не оконченных) играх
create or replace view ActiveDevelopmentCards
as
select cards.GameId, cards.UserId, cards.Nickname, cards.CardId, cards.CardType
from (ActiveMoves
    natural join DevelopmentCards) cards;