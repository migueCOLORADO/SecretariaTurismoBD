-- =========================================================
-- MODELO RELACIONAL: Secretaría de Turismo
-- Motor: MySQL 8.x (InnoDB)
-- Incluye: Tablas + PK/FK + CHECK (MySQL 8+) + Índices + Vistas
-- =========================================================

-- -------------------------------
-- 1) Crear base de datos (si no existe) y seleccionarla
-- -------------------------------
CREATE DATABASE IF NOT EXISTS turismo_db;                               -- Crea la BD si no existe
USE turismo_db;                                                        -- Usa la BD para ejecutar el resto del script

-- -------------------------------
-- 2) Tabla: LugarTuristico
-- -------------------------------
CREATE TABLE IF NOT EXISTS LugarTuristico (                             -- Crea tabla de lugares turísticos
  RNT              INT NOT NULL,                                        -- Identificador del lugar (RNT)
  nombre           VARCHAR(100) NOT NULL,                               -- Nombre del lugar (obligatorio)
  descripcion      VARCHAR(255) NOT NULL,                               -- Descripción general (obligatorio)
  recomendaciones  VARCHAR(200) NULL,                                   -- Recomendaciones de temporada (opcional)
  latitud          DECIMAL(9,6) NOT NULL,                               -- Latitud (obligatorio, con precisión)
  longitud         DECIMAL(9,6) NOT NULL,                               -- Longitud (obligatorio, con precisión)
  activo           TINYINT(1) NOT NULL DEFAULT 1,                       -- Flag lógico (1=activo, 0=inactivo)
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,         -- Fecha de creación
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP          -- Fecha de última actualización (por defecto ahora)
                   ON UPDATE CURRENT_TIMESTAMP,                         -- Actualiza automáticamente al hacer UPDATE
  PRIMARY KEY (RNT),                                                   -- Define PK
  CONSTRAINT ck_latitud  CHECK (latitud  BETWEEN -90 AND 90),           -- Valida rango de latitud (MySQL 8+)
  CONSTRAINT ck_longitud CHECK (longitud BETWEEN -180 AND 180)          -- Valida rango de longitud (MySQL 8+)
) ENGINE=InnoDB;                                                       -- Define motor InnoDB para soportar FKs

-- Índice para búsquedas por nombre (consultas públicas frecuentes)
CREATE INDEX idx_lugar_nombre ON LugarTuristico (nombre);               -- Acelera búsquedas / LIKE por nombre

-- -------------------------------
-- 3) Tabla: Servicio
-- -------------------------------
CREATE TABLE IF NOT EXISTS Servicio (                                   -- Crea tabla de servicios
  idServicio        INT NOT NULL AUTO_INCREMENT,                        -- PK autoincremental
  nombre            VARCHAR(100) NOT NULL,                              -- Nombre del servicio
  tipoServicio      VARCHAR(20) NOT NULL,                               -- Tipo: alojamiento/actividad/recorrido
  caracteristicas   VARCHAR(255) NULL,                                  -- Texto descriptivo de características
  precioReferencial DECIMAL(12,2) NOT NULL,                             -- Precio referencial con decimales
  activo            TINYINT(1) NOT NULL DEFAULT 1,                      -- Flag lógico (activo/inactivo)
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,        -- Fecha creación
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP         -- Fecha actualización
                   ON UPDATE CURRENT_TIMESTAMP,                         -- Auto-actualiza en UPDATE
  PRIMARY KEY (idServicio),                                             -- Define PK
  CONSTRAINT ck_precio_ref CHECK (precioReferencial >= 0),              -- Evita precios negativos (MySQL 8+)
  CONSTRAINT ck_tipo_servicio CHECK (tipoServicio IN                    -- Dominios permitidos
    ('alojamiento','actividad','recorrido')                             -- Ajusta si agregas más tipos
  )
) ENGINE=InnoDB;                                                       -- InnoDB requerido para integridad referencial

-- Índice para filtrar por tipo de servicio (muy común en listados)
CREATE INDEX idx_servicio_tipo ON Servicio (tipoServicio);              -- Acelera WHERE tipoServicio=...

-- -------------------------------
-- 4) Tabla puente N:M: LugarServicio
--    Representa "un lugar ofrece un servicio"
-- -------------------------------
CREATE TABLE IF NOT EXISTS LugarServicio (                              -- Crea tabla intermedia N:M
  RNT         INT NOT NULL,                                             -- FK a LugarTuristico
  idServicio  INT NOT NULL,                                             -- FK a Servicio
  disponible  TINYINT(1) NOT NULL DEFAULT 1,                            -- Permite deshabilitar servicio en el lugar
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,              -- Fecha creación del vínculo
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP               -- Fecha actualización del vínculo
              ON UPDATE CURRENT_TIMESTAMP,                              -- Auto-actualiza en UPDATE
  PRIMARY KEY (RNT, idServicio),                                        -- PK compuesta: evita duplicados por par
  CONSTRAINT fk_ls_lugar FOREIGN KEY (RNT)                              -- Define FK al lugar
    REFERENCES LugarTuristico (RNT)                                     -- Referencia PK LugarTuristico
    ON UPDATE CASCADE                                                   -- Propaga cambios de PK (raro)
    ON DELETE RESTRICT,                                                 -- Evita borrar lugar si tiene servicios asociados
  CONSTRAINT fk_ls_servicio FOREIGN KEY (idServicio)                    -- Define FK al servicio
    REFERENCES Servicio (idServicio)                                    -- Referencia PK Servicio
    ON UPDATE CASCADE                                                   -- Propaga cambios de PK (raro)
    ON DELETE RESTRICT                                                  -- Evita borrar servicio si está asociado
) ENGINE=InnoDB;                                                       -- InnoDB

-- Índice para buscar lugares por un servicio (ej: “dónde hay alojamiento”)
CREATE INDEX idx_lugarservicio_servicio ON LugarServicio (idServicio);  -- Acelera joins/filters por idServicio

-- -------------------------------
-- 5) Tabla: Consulta
--    Registra consultas por un lugar específico
-- -------------------------------
CREATE TABLE IF NOT EXISTS Consulta (                                    -- Crea tabla de consultas
  idConsulta      INT NOT NULL AUTO_INCREMENT,                           -- PK autoincremental
  fecha           DATETIME NOT NULL,                                     -- Fecha/hora de la consulta (entrada del sistema)
  tipoInfoSolicit VARCHAR(30) NOT NULL,                                  -- Tipo de info solicitada
  RNT             INT NOT NULL,                                          -- FK al lugar consultado
  canal           VARCHAR(30) NULL,                                      -- Canal opcional (web/telefono/etc.)
  PRIMARY KEY (idConsulta),                                              -- Define PK
  CONSTRAINT fk_consulta_lugar FOREIGN KEY (RNT)                         -- Define FK al lugar
    REFERENCES LugarTuristico (RNT)                                      -- Referencia PK LugarTuristico
    ON UPDATE CASCADE                                                    -- Propaga cambios de PK (raro)
    ON DELETE RESTRICT                                                   -- Evita borrar lugar si hay historial de consultas
) ENGINE=InnoDB;                                                         -- InnoDB

-- Índice compuesto para analítica por lugar y tiempo (top lugares / tendencias)
CREATE INDEX idx_consulta_lugar_fecha ON Consulta (RNT, fecha);          -- Acelera GROUP BY/ORDER BY por tiempo

-- Índice por tipo de info para analítica por categoría
CREATE INDEX idx_consulta_tipoinfo ON Consulta (tipoInfoSolicit);        -- Acelera filtros y agrupaciones por tipo
