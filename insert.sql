-- Создадим пользователей (таблица Users)
insert into Users (UserName, Password, Nickname, Rating)
values ('user1', '123451', 'Max', 9),
       ('user2', '123452', 'Kirill', 2),
       ('user3', '123453', 'Farit', 5),
       ('user4', '123454', 'Alexey', 0),
       ('user5', '123455', 'Alexandr', 0),
       ('user6', '123456', 'Ilya', 4),
       ('user7', '123457', 'Danil', 0),
       ('user8', '123458', 'Stanislav', 10),
       ('user9', '123459', 'Andrey', 0);

-- Создадим игры (партии) (таблица Games)
insert into Games (StartTime, EndTime, WinningPlayerId)
values (now(), null, 5),
       (timestamp '2023-01-12 15:47:15', timestamp '2023-01-12 16:32:13', 3);

-- Создадим игроков (таблица Players)
insert into Players (UserId, GameId, Score)
values (1, 2, 8),
       (3, 2, 5),
       (8, 2, 10),
       (2, 1, 2),
       (6, 1, 4),
       (1, 1, 1);

-- Создадим игровые доски для каждой игры (таблица Cells)
do
$$
    declare
        pos       int;
        board     resource_type_t[];
        cell_type resource_type_t;
    begin
        for game in 1..2
            loop
                board = getRandomBoard();
                pos := 1;
                foreach cell_type in array board
                    loop
                        insert into Cells (GameId, CellType, NumberForMining, Position)
                        values (game, cell_type, getRandomBetween(2, 12), pos);

                        pos := pos + 1;
                    end loop;
            end loop;
    end;
$$;
end;

-- Выдадим случайные ресурсы игрокам (таблица Resources)
do
$$
    declare
        resource_id    int               := 1;
        players        int[];
        player         int;
        resource_types resource_type_t[] := array ['wood', 'clay', 'wool', 'grain', 'ore'];
        resource       resource_type_t;
    begin
        players := array(
                select p.PlayerId
                from Players p
            );
        foreach player in array players
            loop
                foreach resource in array resource_types
                    loop
                        insert into Resources (ResourceId, PlayerId, ResourceType, Count)
                        values (resource_id, player, resource, getRandomBetween(0, 5));

                        resource_id := resource_id + 1;
                    end loop;
            end loop;
    end;
$$;
end;

-- Создадим ходы (таблица Moves)
do
$$
    declare
        move_id int := 1;
        players int[];
        player  int;
    begin
        for game_id in 1..2
            loop
                players := array(
                        select p.PlayerId
                        from Players p
                        where p.GameId = game_id
                    );
                for round in 1..getRandomBetween(2, 10)
                    loop
                        foreach player in array players
                            loop
                                insert into Moves (PlayerId, GameId, DicesValue)
                                values (player, game_id, getRandomBetween(2, 12));

                                move_id := move_id + 1;
                            end loop;
                    end loop;
            end loop;
    end;
$$;
end;

-- Создадим обмены (таблица ResourceExchanges)
do
$$
    declare
        exchange_id    int               := 1;
        players        int[];
        player         int;
        current_player int;
        move_id        int;
        moves          int[];
        resource_types resource_type_t[] := array ['wood', 'clay', 'wool', 'grain', 'ore'];
        res            resource_type_t;
    begin
        for game_id in 1..2
            loop
                moves := array(
                        select m.MoveId
                        from Moves m
                        where m.GameId = game_id
                    );

                foreach move_id in array moves
                    loop
                        select m.PlayerId
                        into strict current_player
                        from Moves m
                        where m.GameId = game_id
                          and m.MoveId = move_id
                        limit 1;

                        players := array(
                                select p.PlayerId
                                from Players p
                                where p.GameId = game_id
                                  and p.Playerid != current_player
                            );
                        foreach player in array players
                            loop
                                foreach res in array resource_types
                                    loop
                                        if random() < 0.1 then
                                            insert into ResourceExchanges (ExchangeId, MoveId, WithPlayerId, Resource, Count)
                                            values (exchange_id, move_id, player, res, -5 + getRandomBetween(0, 10));

                                            exchange_id := exchange_id + 1;
                                        end if;
                                    end loop;
                            end loop;
                    end loop;
            end loop;
    end;
$$;
end;

-- Заполним таблицу построек (таблица Buildings)
do
$$
    declare
        build_id    int            := 1;
        move_id     int            := 1;
        moves       int[];
        build_types build_type_t[] := array ['road', 'settlement', 'city'];
        build_type  build_type_t;
    begin
        for game_id in 1..2
            loop
                moves := array(
                        select m.MoveId
                        from Moves m
                        where m.GameId = game_id
                    );

                foreach move_id in array moves
                    loop
                        for pos in 1..52 -- всего доступных для строительства позиций: 52
                            loop
                                foreach build_type in array build_types
                                    loop
                                        if random() < 0.015 then
                                            insert into Buildings (BuildingId, MoveId, BuildingType, Position)
                                            values (build_id, move_id, build_type, pos);

                                            build_id := build_id + 1;
                                        end if;
                                    end loop;
                            end loop;
                    end loop;
            end loop;
    end;
$$;
end;

-- Заполним таблицу купленных карт развития (таблица DevelopmentCard)
do
$$
    declare
        card_id    int            := 1;
        move_id     int            := 1;
        moves       int[];
        cards_types card_type_t[] := array ['knight', 'monopoly', 'road_building', 'year_of_abundance', 'winning_point'];
        card_type   card_type_t;
    begin
        for game_id in 1..2
            loop
                moves := array(
                        select m.MoveId
                        from Moves m
                        where m.GameId = game_id
                    );

                foreach move_id in array moves
                    loop
                        foreach card_type in array cards_types
                            loop
                                if random() < 0.1 then
                                    insert into DevelopmentCards (CardId, MoveId, CardType)
                                    values (card_id, move_id, card_type);

                                    card_id := card_id + 1;
                                end if;
                            end loop;
                    end loop;
            end loop;
    end;
$$;
end;