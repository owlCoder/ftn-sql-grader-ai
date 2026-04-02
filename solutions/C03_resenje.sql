-- ============================================================
-- ForgeBoard - SQL skripta za kreiranje tabela
-- MySQL baza podataka
-- ============================================================

-- Opciono: Kreiranje baze (ako ne postoji)
-- CREATE DATABASE IF NOT EXISTS forgeboard
-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE forgeboard;

-- ============================================================
-- 1. Tabela: users (korisnici)
-- ============================================================
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(40) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `email` VARCHAR(255) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `profile_image` VARCHAR(255) NULL, -- putanja ili base64 string
    `role` ENUM('player', 'admin') NOT NULL DEFAULT 'player',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_username` (`username`),
    UNIQUE KEY `uk_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. Tabela: games (globalni katalog igara)
-- ============================================================
DROP TABLE IF EXISTS `games`;
CREATE TABLE `games` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(120) NOT NULL,
    `description` TEXT NOT NULL,
    `cover_image` VARCHAR(255) NULL,
    `min_players` TINYINT UNSIGNED NOT NULL CHECK (`min_players` >= 1),
    `max_players` TINYINT UNSIGNED NOT NULL CHECK (`max_players` >= `min_players`),
    `duration_min` SMALLINT UNSIGNED NOT NULL CHECK (`duration_min` >= 5),
    `weight` DECIMAL(3,2) NOT NULL CHECK (`weight` BETWEEN 1.0 AND 5.0),
    `year_published` SMALLINT UNSIGNED NOT NULL CHECK (`year_published` BETWEEN 1900 AND YEAR(CURDATE())),
    `publisher` VARCHAR(100) NOT NULL,
    `created_by` INT UNSIGNED NULL, -- admin koji je dodao igru (opciono)
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_games_name` (`name`),
    INDEX `idx_games_year` (`year_published`),
    INDEX `idx_games_weight` (`weight`),
    CONSTRAINT `fk_games_created_by` FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. Tabela: mechanics (mehanike)
-- ============================================================
DROP TABLE IF EXISTS `mechanics`;
CREATE TABLE `mechanics` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(80) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_mechanics_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. Tabela: game_mechanics (M:N između igara i mehanika)
-- ============================================================
DROP TABLE IF EXISTS `game_mechanics`;
CREATE TABLE `game_mechanics` (
    `game_id` INT UNSIGNED NOT NULL,
    `mechanic_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`game_id`, `mechanic_id`),
    CONSTRAINT `fk_gamemech_game` FOREIGN KEY (`game_id`) REFERENCES `games`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_gamemech_mechanic` FOREIGN KEY (`mechanic_id`) REFERENCES `mechanics`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. Tabela: user_games (lična kolekcija - M:N korisnik↔igra)
-- ============================================================
DROP TABLE IF EXISTS `user_games`;
CREATE TABLE `user_games` (
    `user_id` INT UNSIGNED NOT NULL,
    `game_id` INT UNSIGNED NOT NULL,
    `status` ENUM('owned', 'wishlist', 'previously_owned') NOT NULL DEFAULT 'owned',
    `personal_rating` TINYINT UNSIGNED NULL CHECK (`personal_rating` BETWEEN 1 AND 10),
    `notes` TEXT NULL,
    `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`, `game_id`),
    INDEX `idx_usergames_status` (`status`),
    CONSTRAINT `fk_usergames_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_usergames_game` FOREIGN KEY (`game_id`) REFERENCES `games`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. Tabela: sessions (sesije igranja)
-- ============================================================
DROP TABLE IF EXISTS `sessions`;
CREATE TABLE `sessions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `game_id` INT UNSIGNED NOT NULL,
    `creator_id` INT UNSIGNED NOT NULL, -- korisnik koji je kreirao sesiju
    `played_at` DATE NOT NULL,
    `duration_minutes` SMALLINT UNSIGNED NOT NULL CHECK (`duration_minutes` > 0),
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_sessions_played_at` (`played_at`),
    CONSTRAINT `fk_sessions_game` FOREIGN KEY (`game_id`) REFERENCES `games`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sessions_creator` FOREIGN KEY (`creator_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `chk_played_at_not_future` CHECK (`played_at` <= CURDATE())
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. Tabela: session_players (učesnici sesije - M:N)
-- ============================================================
DROP TABLE IF EXISTS `session_players`;
CREATE TABLE `session_players` (
    `session_id` INT UNSIGNED NOT NULL,
    `user_id` INT UNSIGNED NOT NULL,
    `score` INT NULL, -- poeni koje je igrač ostvario
    `winner` BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (`session_id`, `user_id`),
    INDEX `idx_sessionplayers_winner` (`winner`),
    CONSTRAINT `fk_sessionplayers_session` FOREIGN KEY (`session_id`) REFERENCES `sessions`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sessionplayers_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. Tabela: reviews (recenzije korisnika na igre)
-- ============================================================
DROP TABLE IF EXISTS `reviews`;
CREATE TABLE `reviews` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` INT UNSIGNED NOT NULL,
    `game_id` INT UNSIGNED NOT NULL,
    `title` VARCHAR(200) NOT NULL,
    `body` TEXT NOT NULL,
    `rating` TINYINT UNSIGNED NOT NULL CHECK (`rating` BETWEEN 1 AND 10),
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_reviews_user_game` (`user_id`, `game_id`), -- jedinstvena recenzija po (user, game)
    INDEX `idx_reviews_game_rating` (`game_id`, `rating`),
    CONSTRAINT `fk_reviews_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_reviews_game` FOREIGN KEY (`game_id`) REFERENCES `games`(`id`) ON DELETE CASCADE,
    CONSTRAINT `chk_review_body_length` CHECK (CHAR_LENGTH(`body`) >= 50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 9. Tabela: audit_logs (evidencija aktivnosti)
-- ============================================================
DROP TABLE IF EXISTS `audit_logs`;
CREATE TABLE `audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` INT UNSIGNED NULL, -- može biti NULL za akcije gosta (npr. neuspela prijava)
    `action` VARCHAR(50) NOT NULL,
    `details` TEXT NULL,
    `ip_address` VARCHAR(45) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_audit_user` (`user_id`),
    INDEX `idx_audit_action` (`action`),
    INDEX `idx_audit_created` (`created_at`),
    CONSTRAINT `fk_audit_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- Kraj SQL skripte
-- ============================================================