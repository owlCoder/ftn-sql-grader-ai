-- ============================================================
-- Wavely - SQL skripta za kreiranje tabela
-- MySQL baza podataka
-- ============================================================

-- Opciono: Kreiranje baze (ako ne postoji)
-- CREATE DATABASE IF NOT EXISTS wavely
-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE wavely;

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
    `profile_image` VARCHAR(255) NULL,
    `role` ENUM('listener', 'admin') NOT NULL DEFAULT 'listener',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_username` (`username`),
    UNIQUE KEY `uk_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. Tabela: artists (izvođači)
-- ============================================================
DROP TABLE IF EXISTS `artists`;
CREATE TABLE `artists` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `genre` ENUM('Pop', 'Rock', 'Hip-Hop', 'Electronic', 'Jazz', 'R&B', 'Classical') NOT NULL,
    `country` VARCHAR(60) NULL,
    `bio` TEXT NULL,
    `image` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_artists_name` (`name`),
    INDEX `idx_artists_genre` (`genre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. Tabela: tracks (pesme)
-- ============================================================
DROP TABLE IF EXISTS `tracks`;
CREATE TABLE `tracks` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(120) NOT NULL,
    `artist_id` INT UNSIGNED NOT NULL,
    `duration_sec` INT UNSIGNED NOT NULL CHECK (`duration_sec` >= 1),
    `album` VARCHAR(120) NOT NULL,
    `release_year` SMALLINT UNSIGNED NOT NULL CHECK (`release_year` BETWEEN 1900 AND YEAR(CURDATE())),
    `cover_image` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_tracks_artist` (`artist_id`),
    INDEX `idx_tracks_genre` ( -- žanr se dobija JOIN-om sa artist, ali može i denormalizovano; ovde ostavljamo samo foreign key
    ),
    CONSTRAINT `fk_tracks_artist` FOREIGN KEY (`artist_id`) REFERENCES `artists`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. Tabela: user_artists (M:N praćenje izvođača)
-- ============================================================
DROP TABLE IF EXISTS `user_artists`;
CREATE TABLE `user_artists` (
    `user_id` INT UNSIGNED NOT NULL,
    `artist_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`user_id`, `artist_id`),
    CONSTRAINT `fk_userartists_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_userartists_artist` FOREIGN KEY (`artist_id`) REFERENCES `artists`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. Tabela: user_tracks (biblioteka - M:N korisnik ↔ pesma)
-- ============================================================
DROP TABLE IF EXISTS `user_tracks`;
CREATE TABLE `user_tracks` (
    `user_id` INT UNSIGNED NOT NULL,
    `track_id` INT UNSIGNED NOT NULL,
    `saved_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`, `track_id`),
    INDEX `idx_usertracks_saved_at` (`saved_at`),
    CONSTRAINT `fk_usertracks_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_usertracks_track` FOREIGN KEY (`track_id`) REFERENCES `tracks`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. Tabela: playlists (plejliste)
-- ============================================================
DROP TABLE IF EXISTS `playlists`;
CREATE TABLE `playlists` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(80) NOT NULL,
    `description` TEXT NULL,
    `cover_image` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_playlists_user` (`user_id`),
    CONSTRAINT `fk_playlists_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. Tabela: playlist_tracks (M:N plejlista ↔ pesme sa redosledom)
-- ============================================================
DROP TABLE IF EXISTS `playlist_tracks`;
CREATE TABLE `playlist_tracks` (
    `playlist_id` INT UNSIGNED NOT NULL,
    `track_id` INT UNSIGNED NOT NULL,
    `position` INT UNSIGNED NOT NULL CHECK (`position` >= 1),
    PRIMARY KEY (`playlist_id`, `track_id`),
    UNIQUE KEY `uk_playlist_position` (`playlist_id`, `position`),
    CONSTRAINT `fk_playlisttracks_playlist` FOREIGN KEY (`playlist_id`) REFERENCES `playlists`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_playlisttracks_track` FOREIGN KEY (`track_id`) REFERENCES `tracks`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. Tabela: audit_logs (evidencija aktivnosti)
-- ============================================================
DROP TABLE IF EXISTS `audit_logs`;
CREATE TABLE `audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` INT UNSIGNED NULL,
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