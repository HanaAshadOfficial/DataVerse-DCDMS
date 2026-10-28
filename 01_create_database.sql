-- ============================================================================
-- Project      : Department Communication Database Management System (DCDMS)
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Team         : DataVerse
-- Script       : 01_create_database.sql
-- Purpose      : Create and select the DCDMS MySQL database with UTF-8 Unicode
--                encoding suitable for MySQL Server 8.0 / 8.4 & MySQL Workbench.
-- ============================================================================

SET SESSION sql_notes = 0;
DROP DATABASE IF EXISTS dcdms_db;
SET SESSION sql_notes = 1;

CREATE DATABASE dcdms_db
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE dcdms_db;
