CREATE OR REPLACE FUNCTION apostar(character varying, character varying)
  RETURNS void AS
$BODY$
DECLARE
carta1 integer;
carta2 integer;
vector_juego INTEGER[];
vect_incognitas INTEGER[];
vect_vista INTEGER[];
turno INTEGER;
punt_1 INTEGER;
punt_2 INTEGER;
ganador INTEGER := 0;
id_jueg INTEGER;
jug_1 integer;
jug_2 integer;
nom_jueg varchar(30);
punt_total integer;

BEGIN

carta1 := posicion($1);--convierte los valores de posiciones a numeros del vector
carta2 := posicion($2);

IF (select j_estado from juego where j_estado = true) is null THEN --pregunta si hay algun juego iniciado
	RAISE NOTICE 'no hay un juego iniciado, inicie un juego';
ELSE--sino, selecciona los valores que usara en el juego y calcula si esta correcto

	SELECT j_id, j_o_cartas,j_j_cartas,j_turno,j_nombre
	INTO id_jueg, vector_juego,vect_incognitas,turno,nom_jueg
	FROM juego WHERE j_estado = true;


	FOR i IN 1..16 LOOP
		vect_vista[i]:= vect_incognitas[i];--se asigna el vector incognita a vector vista, el vector vista sera el q mostrara la informacion en pantalla
	END LOOP;


	IF vect_incognitas[carta1] != 0 or vect_incognitas[carta2] != 0 THEN
		RAISE NOTICE 'UNO DE LOS VALORES YA HA SIDO ELEGIDO';
	ELSEIF carta1 = carta2 or carta1 = 17 or carta2 = 17 THEN	
		RAISE NOTICE 'Ingrese correctamente los valores solicitados, puede que esten fuera de rango';
	ELSE
		IF vector_juego[carta1] = vector_juego[carta2] THEN
			RAISE NOTICE 'Valores iguales "%" y "%"', vector_juego[carta1],vector_juego[carta2];
			vect_incognitas[carta1] := vector_juego[carta1];
			vect_incognitas[carta2] := vector_juego[carta2];
	
			UPDATE juego
			set j_turno = turno,
			j_o_cartas = vector_juego,
			j_j_cartas = vect_incognitas
			where j_id = id_jueg;
	
			IF turno = 1 THEN	
				UPDATE puntaje
				set p_jug1 = p_jug1 + 1
				where p_juego_id = id_jueg;	
			ELSE 
				UPDATE puntaje
				set p_jug2 = p_jug2 + 1
				where p_juego_id = id_jueg;	
			END IF;
	
		ELSE		    
			RAISE NOTICE 'NO SON IGUALES "%" y "%"',vector_juego[carta1],vector_juego[carta2];
	
		END IF;
	
			vect_vista[carta1] := vector_juego[carta1];
			vect_vista[carta2] := vector_juego[carta2];
		
		IF turno = 1 THEN
			turno := 2;
		ELSE
			turno := 1;
		END IF;
	
		UPDATE juego
		SET j_turno = turno
		WHERE j_id = id_jueg;
	END IF;
	
	RAISE NOTICE '            COLUMNA'; 
	RAISE NOTICE '        ---------------';
	RAISE NOTICE '        [a] [b] [c] [d]';
	RAISE NOTICE '';
	RAISE NOTICE 'F| [1]  [%] [%] [%] [%]', vect_vista[1], vect_vista[2], vect_vista[3], vect_vista[4];
	RAISE NOTICE 'I| [2]  [%] [%] [%] [%]', vect_vista[5], vect_vista[6], vect_vista[7], vect_vista[8];
	RAISE NOTICE 'L| [3]  [%] [%] [%] [%]', vect_vista[9], vect_vista[10], vect_vista[11], vect_vista[12];
	RAISE NOTICE 'A| [4]  [%] [%] [%] [%]', vect_vista[13], vect_vista[14], vect_vista[15], vect_vista[16];
	RAISE NOTICE '';

        RAISE NOTICE '|---------------------|';
	RAISE NOTICE '|TURNO DEL JUGADOR "%"', turno;
	
	select j_jug1,j_jug2 
	into jug_1,jug_2
	from juego 
	where j_estado = true;
	
	RAISE notice '|Jugador 1 es: "%"',(select nombre_jug from jugador where id_jug = jug_1);
	RAISE notice '|Jugador 2 es: "%"',(select nombre_jug from jugador where id_jug = jug_2);
	RAISE NOTICE '|---------------------';


	SELECT p_jug1, p_jug2
	INTO punt_1, punt_2
	FROM puntaje, juego WHERE p_juego_id = j_id AND j_id = id_jueg;

	RAISE NOTICE '|---------------------|';
	RAISE NOTICE '|PUNTAJES';
	RAISE NOTICE '|Jugador 1: %', punt_1;
	RAISE NOTICE '|Jugador 2: %', punt_2;
	RAISE NOTICE '|---------------------|';

	punt_total := punt_1 + punt_2;
	
	IF punt_total = 8 THEN
	
		IF punt_1 > punt_2 THEN
			ganador := (select j_jug1 :: integer from juego where j_id = id_jueg);	
			RAISE NOTICE 'EL GANADOR ES EL JUGADOR: %', ganador;		
		ELSEIF punt_1 < punt_2 THEN 
			ganador := (select j_jug2 :: integer from juego where j_id = id_jueg);
			RAISE NOTICE 'EL GANADOR ES EL JUGADOR: %', ganador;
		ELSE
			RAISE NOTICE 'EMPATE';			
		END IF;
		
		RAISE NOTICE '¡¡¡JUEGO TERMINADO!!!...¡¡¡JUEGO TERMINADO!!!...¡¡¡JUEGO TERMINADO!!!';		
		
		UPDATE juego
		SET j_terminado = true, j_estado = false
		WHERE j_id = id_jueg;

		UPDATE jugador
		SET ganados_jug = ganados_jug + 1
		WHERE id_jug = ganador;	
	
          	insert into respaldo(r_fecha, r_hora, r_jug1, r_jug2, r_nombre, r_o_cartas,r_j_cartas, r_ganador)
		values(current_date,current_time,jug_1, jug_2, nom_jueg, vector_juego, vect_incognitas, ganador);
	
	END IF;
END IF;
END;
$BODY$
  LANGUAGE plpgsql;  
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION iniciar_juego(nombrejuego character varying)
  RETURNS void AS
$BODY$
DECLARE
validacion_activo boolean := false;
validacion_nombre varchar;
juegoId int := 0;
jug_1 integer;
jug_2 integer;
validacion_terminado boolean;

BEGIN
select j_estado,j_jug1,j_jug2
into validacion_activo,jug_1,jug_2
from juego 
where j_estado = true;

IF ((select j_nombre from juego where j_nombre = nombrejuego) is null) THEN 
	RAISE NOTICE 'No existe el juego con el nombre "%", intente nuevamente o contactese con el administrador', nombrejuego;
ELSE

	select j_terminado into validacion_terminado
	from juego
	where j_nombre = nombrejuego;

	IF validacion_terminado = true THEN
		RAISE NOTICE 'ESTE JUEGO YA ESTA TERMINADO';
	ELSE
		IF validacion_activo is null THEN		
			UPDATE juego 
			SET j_estado = true
			WHERE j_nombre = nombreJuego;

			RAISE NOTICE 'Se ha iniciado el juego con el nombre de: %', nombrejuego;
		ELSE
			RAISE NOTICE 'Ya hay un juego activo, favor de pausar e iniciar el juego deceado';
		END IF;

		select j_estado,j_jug1,j_jug2 
		into validacion_activo,jug_1,jug_2
		from juego 
		where j_estado = true;
	
		raise notice 'Jugador 1 es: "%"',(select nombre_jug from jugador where id_jug = jug_1);
		raise notice 'Jugador 2 es: "%"',(select nombre_jug from jugador where id_jug = jug_2);

		if (select j_turno from juego where j_nombre = nombreJuego) = 2 THEN
			raise notice 'Turno del jugador: "%"',(select nombre_jug from jugador where id_jug = jug_1);
		else
			raise notice 'Turno del jugador: "%"',(select nombre_jug from jugador where id_jug = jug_2);
		end if;
	END IF;


END IF;

END;
$BODY$
  LANGUAGE plpgsql;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION nuevo_jugador(character varying, character varying, character varying)
  RETURNS void AS
$BODY$
DECLARE
admin_validacion integer := 0;
jugador_validacion integer;
BEGIN

UPDATE juego
SET j_estado = false
WHERE j_estado = true;

RAISE NOTICE 'Se ha pausado el juego activo';

select id_admin 
into admin_validacion 
from administrador 
where nombre_admin = $1 
and clave_admin = $3;

select id_jug
into jugador_validacion
from jugador
where nombre_jug = $2;


IF admin_validacion != 0  THEN

	IF jugador_validacion is NULL THEN
		INSERT INTO jugador (nombre_jug, ganados_jug, estado_jug)
		VALUES($2,0,1);		
		RAISE NOTICE 'EL USUARIO "%" FUE INGRESADO CON EXITO', $2;
	ELSE		
		RAISE NOTICE 'YA HAY UN USUARIO REGISTRADO CON ESE NOMBRE';
	END IF;	
ELSE
	RAISE NOTICE 'El NOMBRE O LA CLAVE DEL ADMINISTRADOR SON ERRONEAS, INGRESE NUEVAMENTE';	
END IF;
END;
$BODY$
  LANGUAGE plpgsql;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pausar_juego()
  RETURNS void AS
$BODY$
DECLARE
pausa boolean;
BEGIN

select j_estado 
into pausa
from juego 
where j_estado = true;

IF pausa = true THEN
	UPDATE juego
	SET j_estado = false
	WHERE j_estado = true;

	RAISE NOTICE 'Se ha pausado el juego activo';
ELSE
	RAISE NOTICE 'No se encuentran juegos iniciados';
END IF;

END;
$BODY$
  LANGUAGE plpgsql;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION posicion(character varying)
  RETURNS integer AS
$BODY$
DECLARE
posicion varchar[] := '{1a,1b,1c,1d,2a,2b,2c,2d,3a,3b,3c,3d,4a,4b,4c,4d}';
cont integer := 0;
BEGIN


   for i in 1..17 loop
        cont := cont + 1;        
	IF posicion[i] = $1 THEN		
		return i;
		exit;
	END IF;

	IF posicion[i] is null THEN		
		return i;
		exit;
	END IF;

			
   end loop;

END;
$BODY$
  LANGUAGE plpgsql;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vector_aleatoreo()
  RETURNS real[] AS
$BODY$
DECLARE
vector INTEGER ARRAY[16];
aleatoreo INTEGER;
indice INTEGER:=1;
auxFlag INTEGER:=0;

BEGIN

 LOOP 
   aleatoreo := trunc(random()* 8 + 1);

   for i in 1..16 loop
      if vector[i] = aleatoreo then
        auxFlag:= auxFlag + 1;
      end if;
   end loop;

   if auxFlag = 0 or auxFlag = 1 then
      vector[indice]=aleatoreo;
      indice := indice + 1;
   end if;

   auxFlag := 0;
   
  EXIT WHEN indice = 17;  
 END LOOP; 

 return vector;

END;
$BODY$
  LANGUAGE plpgsql;
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE TABLE administrador
(
  id_admin serial NOT NULL,
  nombre_admin character varying(30),
  clave_admin character varying(7),
  CONSTRAINT administrador_pkey PRIMARY KEY (id_admin )
)

CREATE TABLE juego
(
  j_id serial NOT NULL,
  j_jug1 character varying,
  j_jug2 character varying,
  j_nombre character varying(30),
  j_o_cartas integer[],
  j_j_cartas integer[],
  j_turno integer,
  j_estado boolean,
  j_terminado boolean,
  CONSTRAINT juego_pkey PRIMARY KEY (j_id )
);

CREATE TABLE jugador
(
  id_jug serial NOT NULL,
  nombre_jug character varying(30),
  ganados_jug integer,
  estado_jug integer,
  CONSTRAINT jugador_pkey PRIMARY KEY (id_jug )
);

CREATE TABLE puntaje
(
  p_id serial NOT NULL,
  p_juego_id integer,
  p_jug1 integer,
  p_jug2 integer,
  p_ganador integer,
  CONSTRAINT puntaje_pkey PRIMARY KEY (p_id )
);

CREATE TABLE respaldo
(
  r_id serial NOT NULL,
  r_fecha date NOT NULL,
  r_hora time with time zone NOT NULL,
  r_jug1 character varying,
  r_jug2 character varying,
  r_nombre character varying(30),
  r_o_cartas integer[],
  r_j_cartas integer[],
  r_ganador character varying,
  CONSTRAINT respaldo_pkey PRIMARY KEY (r_id )
);
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crear_juego()
  RETURNS trigger AS
$BODY$
DECLARE
jugador1 INTEGER;
jugador2 INTEGER;
validaNomJug varchar(30);--guarda la variable para ver si existe, si existe el nombre del jugador
vect_respaldo varchar[];
BEGIN



IF TG_OP = 'INSERT' THEN

	select  j_nombre into  validaNomJug from juego where j_nombre = NEW.j_nombre;
	select id_jug into jugador1 from jugador where nombre_jug = NEW.j_jug1;
	select id_jug into jugador2 from jugador where nombre_jug = NEW.j_jug2;

	IF (select id_jug from jugador where nombre_jug = NEW.j_jug1) is NULL 
	or
	(select id_jug from jugador where nombre_jug = NEW.j_jug2) is NULL THEN

		raise notice 'uno de los jugadores no se encuetra registrado en la BBDD';
		return NULL;
   
	ELSE
		IF (select j_nombre from juego where j_nombre = NEW.j_nombre) is NULL THEN 
			NEW.j_jug1 := jugador1;
			NEW.j_jug2 := jugador2;
			NEW.j_o_cartas := vector_aleatoreo();
			NEW.j_turno := 1;
			NEW.j_estado := false;
			NEW.j_terminado := false;

			FOR i IN 1..16 LOOP
				NEW.j_j_cartas[i] := '0';
			END LOOP;

			insert into puntaje(p_juego_id, p_jug1, p_jug2) 
			values (NEW.j_id,0,0);

			UPDATE juego
			SET j_estado = false
			WHERE j_estado = true;      
        
			raise notice 'Se ha generado un nuevo juego para estos usuarios';
			return NEW;	

		ELSE
			raise notice 'El nombre del juego seleccionado ya se encuentra registrado, favor de ingresar otro';
			return NULL;
		END IF;
	END IF;
END IF;

IF TG_OP = 'DELETE' THEN
	RAISE NOTICE 'NO ESTA PERMITIDO BORRAR REGUISTROS';
	return NULL;
END IF;

END;
$BODY$
  LANGUAGE plpgsql;
  
  
  
CREATE TRIGGER crear_juego BEFORE INSERT OR DELETE
ON juego FOR EACH ROW
EXECUTE PROCEDURE crear_juego();--trigger que funciona antes o de hacer un insert o un delete en la tabla juego, esta levanta la funcion crear_jueg()

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
select * from administrador; --consulta la tabla administrador
insert into administrador(nombre_admin, clave_admin)
values ('edgardo','1234567'); --agrega un nuevo administrador

select * from nuevo_jugador('edgardo','andres','1234567');--llenar los  campos para funcionar.
select * from nuevo_jugador('edgardo','edgardo','1234567');--administrador,nombreNuevoJugador,claveAdminstrador
select * from nuevo_jugador('edgardo','juan','1234567');-- si no se ingresan los valores de esa forma no los admitira
select * from nuevo_jugador('edgardo','roberto','1234567');
select * from nuevo_jugador('edgardo','ale','1234567');

select * from jugador;--selecciono la tabla jugador para ver si se ingresaron los registros 

insert into juego(j_jug1, j_jug2, j_nombre)--esto esta pasando por un trigger
values ('edgardo','juan','ejemplo3');--solo se deven poner estos valores para iniciar el juego, los demmas columnas las rellena la funcion que es disparada
--por el trigger
select * from juego;--revisar si se creo el registro

select * from iniciar_juego('ejemplo3');--todos los juegos parten pausados, ingresar el nombre del juego, si no existe, avisa por pantalla
select * from pausar_juego();--pausa todos los juego

select * from apostar('1a','3a');--fila y columna ; fila y columna -- se creo una funcion llamada "posiciones()" esta hace la convercion a un numero de vector

select * from puntaje; --ve los registros de la tabla puntaje
select * from respaldo; -- ve los registros de la tabla respaldo, cuando finaliza un juego esta se rellena con los datos de ese juego y la fecha
