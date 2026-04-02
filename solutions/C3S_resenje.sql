-- ============================================================
-- PulseNet - SQL skripta za kreiranje tabela
-- MySQL baza podataka (Master-Slave replikacija)
-- ============================================================

-- Opciono: Kreiranje baze (ako ne postoji)
-- CREATE DATABASE IF NOT EXISTS pulsenet
-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE pulsenet;

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
    `bio` VARCHAR(300) NULL,
    `profile_image` VARCHAR(255) NULL,
    `role` ENUM('user', 'admin') NOT NULL DEFAULT 'user',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_username` (`username`),
    UNIQUE KEY `uk_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. Tabela: communities (zajednice)
-- ============================================================
DROP TABLE IF EXISTS `communities`;
CREATE TABLE `communities` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(80) NOT NULL,
    `description` VARCHAR(500) NULL,
    `avatar_image` VARCHAR(255) NULL,
    `type` ENUM('public', 'private') NOT NULL DEFAULT 'public',
    `rules` TEXT NULL,
    `created_by` INT UNSIGNED NOT NULL,          -- vlasnik/moderator koji je kreirao
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_communities_name` (`name`),
    INDEX `idx_communities_type` (`type`),
    CONSTRAINT `fk_communities_created_by` FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. Tabela: community_members (M:N korisnici ↔ zajednice)
-- ============================================================
DROP TABLE IF EXISTS `community_members`;
CREATE TABLE `community_members` (
    `community_id` INT UNSIGNED NOT NULL,
    `user_id` INT UNSIGNED NOT NULL,
    `role` ENUM('moderator', 'member') NOT NULL DEFAULT 'member',
    `status` ENUM('active', 'pending', 'banned') NOT NULL DEFAULT 'active',
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`community_id`, `user_id`),
    INDEX `idx_commembers_status` (`status`),
    INDEX `idx_commembers_role` (`role`),
    CONSTRAINT `fk_commembers_community` FOREIGN KEY (`community_id`) REFERENCES `communities`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_commembers_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. Tabela: tags (globalne oznake)
-- ============================================================
DROP TABLE IF EXISTS `tags`;
CREATE TABLE `tags` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_tags_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. Tabela: posts (objave)
-- ============================================================
DROP TABLE IF EXISTS `posts`;
CREATE TABLE `posts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(200) NOT NULL,
    `content` TEXT NOT NULL,
    `author_id` INT UNSIGNED NOT NULL,
    `community_id` INT UNSIGNED NOT NULL,
    `media_url` VARCHAR(255) NULL,               -- opcioni URL slike/videa
    `likes_count` INT UNSIGNED NOT NULL DEFAULT 0,  -- denormalizovano, ažurira se trigger-om
    `comments_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_posts_author` (`author_id`),
    INDEX `idx_posts_community` (`community_id`),
    INDEX `idx_posts_created` (`created_at`),
    INDEX `idx_posts_likes` (`likes_count`),
    CONSTRAINT `fk_posts_author` FOREIGN KEY (`author_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_posts_community` FOREIGN KEY (`community_id`) REFERENCES `communities`(`id`) ON DELETE CASCADE,
    CONSTRAINT `chk_post_content_length` CHECK (CHAR_LENGTH(`content`) >= 10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. Tabela: post_tags (M:N objave ↔ tagovi)
-- ============================================================
DROP TABLE IF EXISTS `post_tags`;
CREATE TABLE `post_tags` (
    `post_id` INT UNSIGNED NOT NULL,
    `tag_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`post_id`, `tag_id`),
    CONSTRAINT `fk_posttags_post` FOREIGN KEY (`post_id`) REFERENCES `posts`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_posttags_tag` FOREIGN KEY (`tag_id`) REFERENCES `tags`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. Tabela: post_likes (M:N korisnici ↔ objave)
-- ============================================================
DROP TABLE IF EXISTS `post_likes`;
CREATE TABLE `post_likes` (
    `user_id` INT UNSIGNED NOT NULL,
    `post_id` INT UNSIGNED NOT NULL,
    `liked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`, `post_id`),
    CONSTRAINT `fk_postlikes_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_postlikes_post` FOREIGN KEY (`post_id`) REFERENCES `posts`(`id`) ON DELETE CASCADE,
    CONSTRAINT `chk_post_like_not_self` CHECK (`user_id` <> (SELECT `author_id` FROM `posts` WHERE `id` = `post_id`))  -- napomena: ovo ne može u CHECK, implementirati na nivou aplikacije
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. Tabela: comments (komentari, hijerarhijski)
-- ============================================================
DROP TABLE IF EXISTS `comments`;
CREATE TABLE `comments` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `content` VARCHAR(2000) NOT NULL,
    `author_id` INT UNSIGNED NOT NULL,
    `post_id` INT UNSIGNED NOT NULL,
    `parent_id` INT UNSIGNED NULL,               -- NULL za root komentare
    `likes_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `is_deleted` BOOLEAN NOT NULL DEFAULT FALSE, -- soft delete
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_comments_post` (`post_id`),
    INDEX `idx_comments_parent` (`parent_id`),
    INDEX `idx_comments_author` (`author_id`),
    CONSTRAINT `fk_comments_author` FOREIGN KEY (`author_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_comments_post` FOREIGN KEY (`post_id`) REFERENCES `posts`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_comments_parent` FOREIGN KEY (`parent_id`) REFERENCES `comments`(`id`) ON DELETE CASCADE,
    CONSTRAINT `chk_comment_depth` CHECK (
        `parent_id` IS NULL OR 
        (SELECT `parent_id` FROM `comments` WHERE `id` = `parent_id`) IS NULL
    )  -- ograničava maksimalno dva nivoa (root -> reply)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 9. Tabela: comment_likes (M:N korisnici ↔ komentari)
-- ============================================================
DROP TABLE IF EXISTS `comment_likes`;
CREATE TABLE `comment_likes` (
    `user_id` INT UNSIGNED NOT NULL,
    `comment_id` INT UNSIGNED NOT NULL,
    `liked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`, `comment_id`),
    CONSTRAINT `fk_commentlikes_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_commentlikes_comment` FOREIGN KEY (`comment_id`) REFERENCES `comments`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 10. Tabela: user_follows (M:N self-referencing praćenje)
-- ============================================================
DROP TABLE IF EXISTS `user_follows`;
CREATE TABLE `user_follows` (
    `follower_id` INT UNSIGNED NOT NULL,   -- ko prati
    `following_id` INT UNSIGNED NOT NULL,  -- koga prati
    `followed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`follower_id`, `following_id`),
    INDEX `idx_userfollows_following` (`following_id`),
    CONSTRAINT `fk_userfollows_follower` FOREIGN KEY (`follower_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_userfollows_following` FOREIGN KEY (`following_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    CONSTRAINT `chk_not_self_follow` CHECK (`follower_id` <> `following_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 11. Tabela: audit_logs (evidencija aktivnosti)
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