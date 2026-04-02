-- ============================================================
-- PulseGrid - SQL skripta za kreiranje tabela
-- MySQL baza podataka (Master-Slave replikacija)
-- ============================================================

-- Opciono: Kreiranje baze (ako ne postoji)
-- CREATE DATABASE IF NOT EXISTS pulsegrid
-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE pulsegrid;

-- ============================================================
-- 1. Tabela: users (korisnici / igrači)
-- ============================================================
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `gamer_tag` VARCHAR(30) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `email` VARCHAR(255) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `profile_image` VARCHAR(255) NULL,
    `role` ENUM('player', 'admin') NOT NULL DEFAULT 'player',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_gamer_tag` (`gamer_tag`),
    UNIQUE KEY `uk_users_email` (`email`),
    CONSTRAINT `chk_gamer_tag_format` CHECK (`gamer_tag` REGEXP '^[a-zA-Z0-9._-]{3,30}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. Tabela: games (katalog igara)
-- ============================================================
DROP TABLE IF EXISTS `games`;
CREATE TABLE `games` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `logo_image` VARCHAR(255) NULL,
    `genre` VARCHAR(50) NOT NULL,
    `max_players_per_team` TINYINT UNSIGNED NOT NULL CHECK (`max_players_per_team` >= 1),
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_games_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. Tabela: teams (timovi)
-- ============================================================
DROP TABLE IF EXISTS `teams`;
CREATE TABLE `teams` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(80) NOT NULL,
    `tag` VARCHAR(6) NOT NULL,
    `logo_image` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `captain_id` INT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_teams_name` (`name`),
    UNIQUE KEY `uk_teams_tag` (`tag`),
    CONSTRAINT `fk_teams_captain` FOREIGN KEY (`captain_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `chk_tag_format` CHECK (`tag` REGEXP '^[A-Z0-9]{2,6}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. Tabela: team_members (M:N igrači ↔ timovi)
-- ============================================================
DROP TABLE IF EXISTS `team_members`;
CREATE TABLE `team_members` (
    `team_id` INT UNSIGNED NOT NULL,
    `user_id` INT UNSIGNED NOT NULL,
    `role` ENUM('captain', 'member') NOT NULL DEFAULT 'member',
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`team_id`, `user_id`),
    INDEX `idx_teammembers_user` (`user_id`),
    CONSTRAINT `fk_teammembers_team` FOREIGN KEY (`team_id`) REFERENCES `teams`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_teammembers_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. Tabela: tournaments (turniri)
-- ============================================================
DROP TABLE IF EXISTS `tournaments`;
CREATE TABLE `tournaments` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(120) NOT NULL,
    `game_id` INT UNSIGNED NOT NULL,
    `format` ENUM('single_elimination', 'double_elimination', 'round_robin') NOT NULL,
    `max_teams` SMALLINT UNSIGNED NOT NULL CHECK (`max_teams` >= 4),
    `registration_deadline` DATETIME NOT NULL,
    `start_date` DATETIME NOT NULL,
    `prize_pool` DECIMAL(12,2) NULL,
    `status` ENUM('pending', 'ongoing', 'completed', 'cancelled') NOT NULL DEFAULT 'pending',
    `created_by` INT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_tournaments_game` (`game_id`),
    INDEX `idx_tournaments_status` (`status`),
    INDEX `idx_tournaments_deadline` (`registration_deadline`),
    CONSTRAINT `fk_tournaments_game` FOREIGN KEY (`game_id`) REFERENCES `games`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_tournaments_creator` FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `chk_deadline_before_start` CHECK (`registration_deadline` < `start_date`),
    CONSTRAINT `chk_max_teams_power_of_two` CHECK (
        `format` IN ('single_elimination', 'double_elimination') 
        AND (`max_teams` & (`max_teams` - 1)) = 0
        OR `format` = 'round_robin'
    ) -- za eliminacione formate max_teams mora biti stepen dvojke
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. Tabela: tournament_registrations (M:N timovi ↔ turniri)
-- ============================================================
DROP TABLE IF EXISTS `tournament_registrations`;
CREATE TABLE `tournament_registrations` (
    `tournament_id` INT UNSIGNED NOT NULL,
    `team_id` INT UNSIGNED NOT NULL,
    `registered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `status` ENUM('pending', 'confirmed', 'disqualified') NOT NULL DEFAULT 'pending',
    `seed` INT UNSIGNED NULL,
    PRIMARY KEY (`tournament_id`, `team_id`),
    INDEX `idx_tournamentreg_team` (`team_id`),
    INDEX `idx_tournamentreg_status` (`status`),
    CONSTRAINT `fk_tournamentreg_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_tournamentreg_team` FOREIGN KEY (`team_id`) REFERENCES `teams`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. Tabela: matches (mečevi)
-- ============================================================
DROP TABLE IF EXISTS `matches`;
CREATE TABLE `matches` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tournament_id` INT UNSIGNED NOT NULL,
    `round` TINYINT UNSIGNED NOT NULL,               -- 1 = prva runda, 2 = četvrtfinale, itd.
    `match_number` INT UNSIGNED NOT NULL,            -- redni broj meča u okviru turnira (za bracket poziciju)
    `team1_id` INT UNSIGNED NULL,                    -- NULL ako još nije poznat (npr. čeka se pobednik prethodnog meča)
    `team2_id` INT UNSIGNED NULL,
    `winner_team_id` INT UNSIGNED NULL,
    `score` VARCHAR(20) NULL,                        -- format "2:0", "3:1"
    `status` ENUM('scheduled', 'ongoing', 'completed') NOT NULL DEFAULT 'scheduled',
    `scheduled_time` DATETIME NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_matches_tournament` (`tournament_id`),
    INDEX `idx_matches_round` (`round`),
    INDEX `idx_matches_status` (`status`),
    CONSTRAINT `fk_matches_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_matches_team1` FOREIGN KEY (`team1_id`) REFERENCES `teams`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_matches_team2` FOREIGN KEY (`team2_id`) REFERENCES `teams`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_matches_winner` FOREIGN KEY (`winner_team_id`) REFERENCES `teams`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. Tabela: match_players (M:N igrači ↔ mečevi)
-- ============================================================
DROP TABLE IF EXISTS `match_players`;
CREATE TABLE `match_players` (
    `match_id` INT UNSIGNED NOT NULL,
    `user_id` INT UNSIGNED NOT NULL,
    `team_id` INT UNSIGNED NOT NULL,                 -- za koji tim je igrač nastupio u ovom meču
    `performance_notes` TEXT NULL,
    PRIMARY KEY (`match_id`, `user_id`),
    INDEX `idx_matchplayers_user` (`user_id`),
    INDEX `idx_matchplayers_team` (`team_id`),
    CONSTRAINT `fk_matchplayers_match` FOREIGN KEY (`match_id`) REFERENCES `matches`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_matchplayers_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_matchplayers_team` FOREIGN KEY (`team_id`) REFERENCES `teams`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 9. Tabela: user_watchlist (M:N igrači ↔ turniri - praćenje)
-- ============================================================
DROP TABLE IF EXISTS `user_watchlist`;
CREATE TABLE `user_watchlist` (
    `user_id` INT UNSIGNED NOT NULL,
    `tournament_id` INT UNSIGNED NOT NULL,
    `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`, `tournament_id`),
    INDEX `idx_watchlist_tournament` (`tournament_id`),
    CONSTRAINT `fk_watchlist_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_watchlist_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 10. Tabela: audit_logs (evidencija aktivnosti)
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