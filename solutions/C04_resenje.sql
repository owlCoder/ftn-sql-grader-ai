-- ============================================================
-- TrailSync - SQL skripta za kreiranje tabela
-- MySQL baza podataka
-- ============================================================

-- Opciono: Kreiranje baze (ako ne postoji)
-- CREATE DATABASE IF NOT EXISTS trailsync
-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE trailsync;

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
    `profile_image` VARCHAR(255) NULL,          -- putanja ili base64
    `role` ENUM('hiker', 'admin') NOT NULL DEFAULT 'hiker',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_username` (`username`),
    UNIQUE KEY `uk_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. Tabela: mountains (planine)
-- ============================================================
DROP TABLE IF EXISTS `mountains`;
CREATE TABLE `mountains` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `elevation_m` INT UNSIGNED NOT NULL,        -- visina planine u metrima
    `region` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_mountains_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. Tabela: trails (planinarske rute)
-- ============================================================
DROP TABLE IF EXISTS `trails`;
CREATE TABLE `trails` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(120) NOT NULL,
    `description` TEXT NOT NULL,
    `cover_image` VARCHAR(255) NULL,
    `length_km` DECIMAL(6,2) NOT NULL CHECK (`length_km` >= 0.1),
    `elevation_m` INT UNSIGNED NOT NULL,
    `difficulty` ENUM('easy', 'moderate', 'hard', 'expert') NOT NULL,
    `est_duration_min` SMALLINT UNSIGNED NOT NULL CHECK (`est_duration_min` >= 10),
    `mountain_id` INT UNSIGNED NOT NULL,
    `created_by` INT UNSIGNED NULL,             -- admin koji je dodao rutu
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_trails_difficulty` (`difficulty`),
    INDEX `idx_trails_length` (`length_km`),
    INDEX `idx_trails_elevation` (`elevation_m`),
    CONSTRAINT `fk_trails_mountain` FOREIGN KEY (`mountain_id`) REFERENCES `mountains`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_trails_created_by` FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. Tabela: terrain_tags (tipovi terena)
-- ============================================================
DROP TABLE IF EXISTS `terrain_tags`;
CREATE TABLE `terrain_tags` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(80) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_terraintags_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. Tabela: trail_tags (M:N rute ↔ tipovi terena)
-- ============================================================
DROP TABLE IF EXISTS `trail_tags`;
CREATE TABLE `trail_tags` (
    `trail_id` INT UNSIGNED NOT NULL,
    `tag_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`trail_id`, `tag_id`),
    CONSTRAINT `fk_trailtags_trail` FOREIGN KEY (`trail_id`) REFERENCES `trails`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_trailtags_tag` FOREIGN KEY (`tag_id`) REFERENCES `terrain_tags`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. Tabela: user_trails (M:N korisnici ↔ rute - lista ruta)
-- ============================================================
DROP TABLE IF EXISTS `user_trails`;
CREATE TABLE `user_trails` (
    `user_id` INT UNSIGNED NOT NULL,
    `trail_id` INT UNSIGNED NOT NULL,
    `status` ENUM('want_to_hike', 'completed') NOT NULL DEFAULT 'want_to_hike',
    `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`, `trail_id`),
    INDEX `idx_usertrails_status` (`status`),
    CONSTRAINT `fk_usertrails_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_usertrails_trail` FOREIGN KEY (`trail_id`) REFERENCES `trails`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. Tabela: ascents (evidencija uspona)
-- ============================================================
DROP TABLE IF EXISTS `ascents`;
CREATE TABLE `ascents` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` INT UNSIGNED NOT NULL,
    `trail_id` INT UNSIGNED NOT NULL,
    `hiked_at` DATE NOT NULL,
    `actual_duration_min` SMALLINT UNSIGNED NOT NULL CHECK (`actual_duration_min` > 0),
    `personal_rating` TINYINT UNSIGNED NOT NULL CHECK (`personal_rating` BETWEEN 1 AND 10),
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_ascents_user` (`user_id`),
    INDEX `idx_ascents_trail` (`trail_id`),
    INDEX `idx_ascents_hiked_at` (`hiked_at`),
    CONSTRAINT `fk_ascents_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_ascents_trail` FOREIGN KEY (`trail_id`) REFERENCES `trails`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `chk_hiked_at_not_future` CHECK (`hiked_at` <= CURDATE())
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. Tabela: hikes (grupni pohodi)
-- ============================================================
DROP TABLE IF EXISTS `hikes`;
CREATE TABLE `hikes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(120) NOT NULL,
    `trail_id` INT UNSIGNED NOT NULL,
    `organizer_id` INT UNSIGNED NOT NULL,
    `scheduled_at` DATETIME NOT NULL,
    `description` TEXT NULL,
    `max_participants` TINYINT UNSIGNED NOT NULL CHECK (`max_participants` BETWEEN 2 AND 50),
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_hikes_scheduled_at` (`scheduled_at`),
    INDEX `idx_hikes_organizer` (`organizer_id`),
    CONSTRAINT `fk_hikes_trail` FOREIGN KEY (`trail_id`) REFERENCES `trails`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_hikes_organizer` FOREIGN KEY (`organizer_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 9. Tabela: hike_participants (M:N korisnici ↔ pohodi)
-- ============================================================
DROP TABLE IF EXISTS `hike_participants`;
CREATE TABLE `hike_participants` (
    `hike_id` INT UNSIGNED NOT NULL,
    `user_id` INT UNSIGNED NOT NULL,
    `status` ENUM('invited', 'confirmed', 'declined') NOT NULL DEFAULT 'invited',
    `responded_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`hike_id`, `user_id`),
    INDEX `idx_hikeparticipants_status` (`status`),
    CONSTRAINT `fk_hikeparticipants_hike` FOREIGN KEY (`hike_id`) REFERENCES `hikes`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_hikeparticipants_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 10. Tabela: audit_logs (evidencija aktivnosti)
-- ============================================================
DROP TABLE IF EXISTS `audit_logs`;
CREATE TABLE `audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` INT UNSIGNED NULL,               -- NULL za akcije gostiju
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