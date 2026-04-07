-- =============================================================================
-- ENT-11683 Multi-License Test Data Seed Script
-- Generated: 2026-04-07 from localhost:3406 (edx.devstack.mysql80)
--
-- Enterprise: Test Multi-License Enterprise
--   UUID (with dashes):  aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
--   UUID (DB char32):    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
--   Slug:                test-multi-enterprise
--   Customer Agreement:  bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
--
-- Subscription Plans (catalog UUID → plan title):
--   11111111...  Leadership Training
--   22222222...  Technical Training
--   33333333...  Compliance Training
--   44444444...  Data Science
--   55555555...  Business Skills
--
-- Databases touched:
--   edxapp, license_manager, enterprise_catalog, enterprise_access
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =============================================================================
-- DATABASE: edxapp
-- =============================================================================
USE edxapp;

-- -----------------------------------------------------------------------------
-- Enterprise Customer: Test Multi-License Enterprise
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `enterprise_enterprisecustomer`
  (`created`, `modified`, `uuid`, `name`, `slug`, `active`, `country`,
   `hide_course_original_price`, `enable_data_sharing_consent`,
   `enforce_data_sharing_consent`, `enable_audit_enrollment`,
   `enable_audit_data_reporting`, `replace_sensitive_sso_username`,
   `enable_autocohorting`, `enable_portal_code_management_screen`,
   `enable_portal_reporting_config_screen`,
   `enable_portal_subscription_management_screen`, `enable_learner_portal`,
   `contact_email`, `customer_type_id`, `site_id`, `enable_slug_login`,
   `enable_portal_saml_configuration_screen`, `default_contract_discount`,
   `enable_analytics_screen`, `enable_integrated_customer_learner_portal_search`,
   `default_language`, `enable_portal_lms_configurations_screen`,
   `sender_alias`, `reply_to`, `hide_labor_market_data`, `enable_universal_link`,
   `enable_browse_and_request`, `enable_learner_portal_offers`,
   `enable_portal_learner_credit_management_screen`,
   `enable_executive_education_2U_fulfillment`, `auth_org_id`,
   `enable_generation_of_api_credentials`, `enable_pathways`, `enable_programs`,
   `enable_demo_data_for_analytics_and_lpr`, `enable_academies`,
   `enable_one_academy`, `disable_expiry_messaging_for_learner_credit`,
   `enable_learner_portal_sidebar_message`, `learner_portal_sidebar_content`,
   `show_videos_in_learner_portal_search_results`, `enable_learner_credit_message_box`)
VALUES
  ('2026-03-27 09:55:19.078770','2026-03-27 10:14:27.217414',
   'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','Test Multi-License Enterprise',
   'test-multi-enterprise',1,'US',0,1,'at_enrollment',0,0,0,0,0,0,0,1,
   'test-multi@example.com',1,2,0,0,NULL,1,1,NULL,0,NULL,NULL,0,0,1,0,0,0,
   NULL,0,1,1,0,0,0,0,0,'',0,1);

-- -----------------------------------------------------------------------------
-- Test Users (auth_user)
-- Passwords are pre-hashed pbkdf2_sha256; all use 'edx' as password
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `auth_user`
  (`id`, `password`, `last_login`, `is_superuser`, `username`, `first_name`,
   `last_name`, `email`, `is_staff`, `is_active`, `date_joined`)
VALUES
  (30,'pbkdf2_sha256$1000000$8rOEuMWmzfQLv94aycw56l$fLceltvHmK9K/MXg/LZLssa2jXsPYV7nPg6ygx9SdtU=',
   NULL,0,'test-multi-alice','','','test-multi-alice@example.com',0,1,'2026-03-27 09:55:19.196669'),
  (31,'pbkdf2_sha256$1000000$WniHtLuSKaqjz1HNNJOy3i$GLa1laBmMvszIPby/DyxT9mxHFPFxN3xTxQlNjOsVv8=',
   NULL,0,'test-multi-bob','','','test-multi-bob@example.com',0,1,'2026-03-27 09:55:19.393960'),
  (32,'pbkdf2_sha256$1000000$yrcveDs6evcIECU7eL0vNI$EjiLxkQ3XtOKmdFS3MC1FeIZfQXi9TLeZ1WBfjR5OHs=',
   NULL,0,'test-multi-carol','','','test-multi-carol@example.com',0,1,'2026-03-27 09:55:19.423720'),
  (33,'pbkdf2_sha256$1000000$7JKjplfxeXHsqu7Gt5IZ2J$4rCD6fYWbsaYfwmwW7b/6dqvRoZZPctqyYWDL2K9cpE=',
   NULL,0,'test-multi-dave','','','test-multi-dave@example.com',0,1,'2026-03-27 09:55:19.445154'),
  (34,'pbkdf2_sha256$1000000$dI1VrO4M5ITXmEwo4pxl2T$JNro9gpDSFLRfb8g1oIU/sFb5jtPJCCj8Z6kFvd6A60=',
   NULL,0,'test-multi-eve','','','test-multi-eve@example.com',0,1,'2026-03-27 09:55:19.465752'),
  (35,'pbkdf2_sha256$1000000$Ndy1JnpjA8ZB4xp39rHEQ3$Uda4TmCxOoIxQgUq/QamQPO3kcSA3Q9ifuHtkJW2bZI=',
   NULL,0,'test-dual-analyst01','','','test-dual-analyst01@example.com',0,1,'2026-04-06 15:07:31.228562'),
  (36,'pbkdf2_sha256$1000000$xz8iNQOo5SO1zngqtFfDrH$dNCvP1oixXQTXdKYVBB215Hdfk/CwDbSDBw89dG5J48=',
   NULL,0,'test-dual-engineer01','','','test-dual-engineer01@example.com',0,1,'2026-04-06 15:07:31.536033'),
  (37,'pbkdf2_sha256$1000000$txxatBsexkzJFJJDAyc8B1$Q/3fPi3dEzMxibeFsyoR4D5Ot/Xa2qqXuXz5u61Ii0M=',
   NULL,0,'test-dual-manager01','','','test-dual-manager01@example.com',0,1,'2026-04-06 15:07:31.842630'),
  (38,'pbkdf2_sha256$1000000$5X10mDbsENhKtagCPWGAUQ$NirroSmCchGEk76bHt+f/njVhWasqfz7dM92wXPG4gY=',
   NULL,0,'test-dual-bizanalyst01','','','test-dual-bizanalyst01@example.com',0,1,'2026-04-06 15:07:32.135595'),
  (39,'pbkdf2_sha256$1000000$j9AMF4nHgo9EKfYCBGaKvj$wTa6pl9LGEtq7rvnFXfvPtObxrwtjsUdxZPBx0sucx4=',
   NULL,0,'test-dual-itpro01','','','test-dual-itpro01@example.com',0,1,'2026-04-06 15:07:32.418548'),
  (40,'pbkdf2_sha256$1000000$RUU1emRAXym4V7kqvoRXM4$t918IaLb9WV/S+G1vjhEFv8cdEUQ/2bIga/DGa0/znQ=',
   NULL,0,'test-dual-exec01','','','test-dual-exec01@example.com',0,1,'2026-04-06 15:07:32.702809'),
  (41,'pbkdf2_sha256$1000000$mqlOiO28g4oSqLsteiIeUW$iV/ENPT4UsmP72advef9cM7afxgmneIcCVX92DR3oFw=',
   NULL,0,'test-dual-mlengineer01','','','test-dual-mlengineer01@example.com',0,1,'2026-04-06 15:07:32.980627'),
  (42,'pbkdf2_sha256$1000000$8pUzscjfwoxrGkkzFtPy7Q$tXGZrk6jjY+uzhWAHpvIeg6kDJesBgVjBtVaZrKsxUo=',
   NULL,0,'test-dual-compliance01','','','test-dual-compliance01@example.com',0,1,'2026-04-06 15:07:33.263073'),
  (43,'pbkdf2_sha256$1000000$MYFpZmU4YWDIrWunjVWJ1x$8d3MrHewQzXdvTc9RWSfM9KQyvj2L7t6t8L2UMvh4J0=',
   NULL,0,'test-dual-techlead01','','','test-dual-techlead01@example.com',0,1,'2026-04-06 15:07:33.541123'),
  (44,'pbkdf2_sha256$1000000$A1z2IjvMFrAHbrHw5AZCMy$62XEa0tqfoO0H3X18nD0K1jnVls13FXQ+vhUBnu+9cA=',
   NULL,0,'test-dual-datascientist01','','','test-dual-datascientist01@example.com',0,1,'2026-04-06 15:07:33.819083'),
  (45,'pbkdf2_sha256$1000000$s2LIBb3Mrfz3nnshyfKMg6$57vNAzkz6+cY0V0RAa9yaJp7PvJBDrcHkRdGdXYbmjg=',
   NULL,0,'test-dual-dataleader01','','','test-dual-dataleader01@example.com',0,1,'2026-04-06 15:07:34.097141'),
  (46,'pbkdf2_sha256$1000000$mWMx00UME3M92h49Svci2U$Zio40KAUNyt3gkyWbjoi2RhsmOEStDyXeUZLSA1GDWs=',
   NULL,0,'test-dual-producteng01','','','test-dual-producteng01@example.com',0,1,'2026-04-06 15:07:34.376609');

-- auth_userprofile rows (required by edxapp for login)
INSERT IGNORE INTO `auth_userprofile` (`user_id`, `name`, `meta`, `courseware`, `language`, `location`, `year_of_birth`, `gender`, `level_of_education`, `mailing_address`, `city`, `country`, `goals`, `bio`, `profile_image_uploaded_at`, `phone_number`, `state`)
SELECT id, username, '{}', 'course.xml', '', '', NULL, NULL, NULL, '', '', NULL, '', NULL, NULL, NULL, NULL
FROM auth_user
WHERE id IN (30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46)
  AND id NOT IN (SELECT user_id FROM auth_userprofile);

-- user_tours_usertour rows (required to avoid 500 on learner portal)
INSERT IGNORE INTO `user_tours_usertour` (`user_id`, `course_home_tour_status`, `show_courseware_tour`, `course_home_explore_tabs_tour_status`)
SELECT id, 0, 0, 0 FROM auth_user
WHERE id IN (30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46)
  AND id NOT IN (SELECT user_id FROM user_tours_usertour);

-- -----------------------------------------------------------------------------
-- Enterprise Customer User Memberships
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `enterprise_enterprisecustomeruser`
  (`id`, `created`, `modified`, `user_id`, `active`, `linked`,
   `enterprise_customer_id`, `should_inactivate_other_customers`,
   `is_relinkable`, `invite_key_id`, `user_fk`)
VALUES
  (11,'2026-03-27 09:55:19.269630','2026-03-27 09:55:19.269630',30,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (12,'2026-03-27 09:55:19.411888','2026-03-27 09:55:19.411888',31,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (13,'2026-03-27 09:55:19.434270','2026-03-27 09:55:19.434270',32,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (14,'2026-03-27 09:55:19.454853','2026-03-27 09:55:19.454853',33,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (15,'2026-03-27 09:55:19.474369','2026-03-27 09:55:19.474369',34,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (16,'2026-03-27 09:59:01.395218','2026-03-27 09:59:01.395218',3, 1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (17,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',35,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (18,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',38,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (19,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',42,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (20,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',45,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (21,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',44,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (22,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',36,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (23,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',40,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (24,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',39,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (25,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',37,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (26,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',41,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (27,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',46,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL),
  (28,'2026-04-06 16:08:05.000000','2026-04-06 16:08:05.000000',43,1,1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0,1,NULL,NULL);

-- -----------------------------------------------------------------------------
-- Enterprise Customer Catalogs (edxapp side — displays in admin portal)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `enterprise_enterprisecustomercatalog`
  (`created`, `modified`, `uuid`, `title`, `content_filter`,
   `enabled_course_modes`, `publish_audit_enrollment_urls`,
   `enterprise_catalog_query_id`, `enterprise_customer_id`)
VALUES
  ('2026-04-06 16:30:36.000000','2026-04-06 16:30:36.000000',
   '11111111111111111111111111111111','Leadership Training Catalog',
   '{"content_type":["courserun","course"],"availability":["Current","Starting Soon","Upcoming"],"level_type":["Introductory","Intermediate","Advanced"],"status":"published"}',
   '["verified","professional","no-id-professional","audit","honor","unpaid-executive-education"]',
   0,NULL,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  ('2026-04-06 16:30:36.000000','2026-04-06 16:30:36.000000',
   '22222222222222222222222222222222','Technical Skills Catalog',
   '{"content_type":["courserun","course"],"availability":["Current","Starting Soon","Upcoming"],"level_type":["Introductory","Intermediate","Advanced"],"status":"published"}',
   '["verified","professional","no-id-professional","audit","honor","unpaid-executive-education"]',
   0,NULL,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  ('2026-04-06 16:30:36.000000','2026-04-06 16:30:36.000000',
   '33333333333333333333333333333333','Compliance Training Catalog',
   '{"content_type":["courserun","course"],"availability":["Current","Starting Soon","Upcoming"],"level_type":["Introductory","Intermediate","Advanced"],"status":"published"}',
   '["verified","professional","no-id-professional","audit","honor","unpaid-executive-education"]',
   0,NULL,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  ('2026-04-06 16:30:36.000000','2026-04-06 16:30:36.000000',
   '44444444444444444444444444444444','Data Science Catalog',
   '{"content_type":["courserun","course"],"availability":["Current","Starting Soon","Upcoming"],"level_type":["Introductory","Intermediate","Advanced"],"status":"published"}',
   '["verified","professional","no-id-professional","audit","honor","unpaid-executive-education"]',
   0,NULL,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  ('2026-04-06 16:30:36.000000','2026-04-06 16:30:36.000000',
   '55555555555555555555555555555555','Business & Strategy Catalog',
   '{"content_type":["courserun","course"],"availability":["Current","Starting Soon","Upcoming"],"level_type":["Introductory","Intermediate","Advanced"],"status":"published"}',
   '["verified","professional","no-id-professional","audit","honor","unpaid-executive-education"]',
   0,NULL,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

-- -----------------------------------------------------------------------------
-- System-Wide Enterprise Role Assignments (edxapp)
-- role_id=2 → enterprise_learner
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `enterprise_systemwideenterpriseuserroleassignment`
  (`id`, `created`, `modified`, `role_id`, `user_id`,
   `applies_to_all_contexts`, `enterprise_customer_id`)
VALUES
  (20,'2026-03-27 09:55:19.344329','2026-03-27 09:55:19.344329',2,30,0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  (21,'2026-03-27 09:55:19.419150','2026-03-27 09:55:19.419150',2,31,0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  (22,'2026-03-27 09:55:19.441199','2026-03-27 09:55:19.441199',2,32,0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  (23,'2026-03-27 09:55:19.461699','2026-03-27 09:55:19.461699',2,33,0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  (24,'2026-03-27 09:55:19.481033','2026-03-27 09:55:19.481033',2,34,0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  (25,'2026-03-27 09:59:01.405457','2026-03-27 09:59:01.405457',2,3, 0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
-- Note: dual users (35-46) use JWT-based implicit roles via SSO provider config,
-- not explicit DB role assignments in edxapp. Add here if your env needs them.


-- =============================================================================
-- DATABASE: license_manager
-- =============================================================================
USE license_manager;

-- -----------------------------------------------------------------------------
-- Plan Types (standard set — insert if not present)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `subscriptions_plantype`
  (`id`, `label`, `description`, `is_paid_subscription`, `ns_id_required`,
   `sf_id_required`, `internal_use_only`)
VALUES
  (1,'Standard Paid','A paid subscription plan',1,1,1,0),
  (2,'OCE','Online Campus Essentials, unpaid subscription plan for academic institutions',0,0,1,0),
  (3,'Trial','Limited free subscription plan for prospective customers',0,0,1,0),
  (4,'Test','Internal edX subscription testing',0,0,0,1);

-- -----------------------------------------------------------------------------
-- Products
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `subscriptions_product`
  (`id`, `name`, `description`, `netsuite_id`, `plan_type_id`, `salesforce_product_id`)
VALUES
  (1,'B2B Paid','B2B Catalog',106,1,NULL),
  (2,'OC Paid','OC Catalog',110,1,NULL),
  (3,'Trial','Trial Catalog',NULL,3,NULL),
  (4,'Test','Test Catalog',NULL,4,NULL),
  (5,'OCE','OCE Catalog',NULL,2,NULL);

-- -----------------------------------------------------------------------------
-- Customer Agreement
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `subscriptions_customeragreement`
  (`created`, `modified`, `uuid`, `enterprise_customer_uuid`,
   `enterprise_customer_slug`, `default_enterprise_catalog_uuid`,
   `disable_expiration_notifications`, `license_duration_before_purge`,
   `enterprise_customer_name`, `disable_onboarding_notifications`,
   `expired_subscription_modal_messaging`, `has_custom_license_expiration_messaging`,
   `enable_auto_applied_subscriptions_with_universal_link`, `button_label_in_modal`,
   `modal_header_text`, `url_for_button_in_modal`, `auto_scaling_increment_percentage`,
   `auto_scaling_max_licenses`, `auto_scaling_threshold_percentage`,
   `enable_auto_scaling_of_current_plan`)
VALUES
  ('2026-03-27 08:35:15.000000','2026-03-27 08:35:15.000000',
   'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
   'test-multi-enterprise','11111111111111111111111111111111',
   0,365,NULL,0,NULL,0,0,NULL,NULL,NULL,NULL,NULL,NULL,0);

-- -----------------------------------------------------------------------------
-- Subscription Plans (5 catalogs for test-multi-enterprise)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `subscriptions_subscriptionplan`
  (`created`, `modified`, `uuid`, `start_date`, `expiration_date`,
   `enterprise_catalog_uuid`, `is_active`, `title`, `salesforce_opportunity_id`,
   `for_internal_use_only`, `num_revocations_applied`, `revoke_max_percentage`,
   `customer_agreement_id`, `expiration_processed`, `is_revocation_cap_enabled`,
   `can_freeze_unused_licenses`, `last_freeze_timestamp`,
   `should_auto_apply_licenses`, `product_id`, `salesforce_opportunity_line_item`,
   `desired_num_licenses`)
VALUES
  -- Plan 1: Leadership Training (catalog 1111...)
  ('2026-01-26 08:54:42.000000','2026-03-27 08:54:42.000000',
   'c1111111111111111111111111111111','2026-01-26 08:54:42.000000','2026-06-25 08:54:42.000000',
   '11111111111111111111111111111111',1,'Test Multi: Leadership Training',
   NULL,0,0,5,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',0,0,0,NULL,0,NULL,NULL,NULL),
  -- Plan 2: Technical Training (catalog 2222...)
  ('2026-02-10 08:54:42.000000','2026-03-27 08:54:42.000000',
   'c2222222222222222222222222222222','2026-02-10 08:54:42.000000','2026-09-23 08:54:42.000000',
   '22222222222222222222222222222222',1,'Test Multi: Technical Training',
   NULL,0,0,5,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',0,0,0,NULL,0,NULL,NULL,NULL),
  -- Plan 3: Compliance Training (catalog 3333...)
  ('2026-02-25 08:54:42.000000','2026-03-27 08:54:42.000000',
   'c3333333333333333333333333333333','2026-02-25 08:54:42.000000','2027-03-27 08:54:42.000000',
   '33333333333333333333333333333333',1,'Test Multi: Compliance Training',
   NULL,0,0,5,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',0,0,0,NULL,0,NULL,NULL,NULL),
  -- Plan 4: Data Science (catalog 4444...)
  ('2026-03-07 08:54:42.000000','2026-04-03 10:30:21.659312',
   'c4444444444444444444444444444444','2026-03-07 08:54:42.000000','2026-09-23 08:54:42.000000',
   '44444444444444444444444444444444',1,'Test Multi: Data Science',
   NULL,0,0,5,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',0,0,0,NULL,0,NULL,NULL,NULL),
  -- Plan 5: Business Skills (catalog 5555...)
  ('2026-03-17 08:54:42.000000','2026-03-27 08:54:42.000000',
   'c5555555555555555555555555555555','2026-03-17 08:54:42.000000','2026-07-25 08:54:42.000000',
   '55555555555555555555555555555555',1,'Test Multi: Business Skills',
   NULL,0,0,5,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',0,0,0,NULL,0,NULL,NULL,NULL);

-- -----------------------------------------------------------------------------
-- Licenses
-- Format: (uuid, status, activation_date, user_email, lms_user_id, plan_uuid, activation_key)
-- Single-license users: alice(30), bob(31), carol(32), dave(33) — 1 plan each
-- Dual-license users (35-46) — 2 plans each (the ENT-11683 multi-license test set)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `subscriptions_license`
  (`created`, `modified`, `uuid`, `status`, `activation_date`, `last_remind_date`,
   `user_email`, `lms_user_id`, `subscription_plan_id`, `activation_key`,
   `assigned_date`, `revoked_date`, `renewed_to_id`, `auto_applied`,
   `expiration_reminder_sent_date`)
VALUES
  -- alice: Leadership + Technical
  ('2026-04-01 06:03:27.000000','2026-04-01 06:03:27.000000','807a65cd2d9011f1bd099a17be7a306d','activated','2024-01-15 09:00:00.000000',NULL,'test-multi-alice@example.com',30,'c1111111111111111111111111111111','807a661d2d9011f1bd099a17be7a306d',NULL,NULL,NULL,0,NULL),
  ('2026-04-01 06:03:27.000000','2026-04-01 06:03:27.000000','807bba772d9011f1bd099a17be7a306d','activated','2024-03-10 09:00:00.000000',NULL,'test-multi-alice@example.com',30,'c2222222222222222222222222222222','807bbac52d9011f1bd099a17be7a306d',NULL,NULL,NULL,0,NULL),
  -- alice: Compliance
  ('2026-04-01 06:03:27.000000','2026-04-01 06:03:27.000000','807bbd3e2d9011f1bd099a17be7a306d','activated','2024-06-01 09:00:00.000000',NULL,'test-multi-alice@example.com',30,'c3333333333333333333333333333333','807bbd742d9011f1bd099a17be7a306d',NULL,NULL,NULL,0,NULL),
  -- bob: Leadership + Technical
  ('2026-04-01 06:04:13.000000','2026-04-01 06:04:13.000000','9bb7e9132d9011f1bd099a17be7a306d','activated','2024-02-01 09:00:00.000000',NULL,'test-multi-bob@example.com',31,'c1111111111111111111111111111111','9bb7e9552d9011f1bd099a17be7a306d',NULL,NULL,NULL,0,NULL),
  ('2026-04-01 06:04:13.000000','2026-04-01 06:04:13.000000','9bb7ed7c2d9011f1bd099a17be7a306d','activated','2024-07-15 09:00:00.000000',NULL,'test-multi-bob@example.com',31,'c2222222222222222222222222222222','9bb7ed952d9011f1bd099a17be7a306d',NULL,NULL,NULL,0,NULL),
  -- carol: Compliance
  ('2026-04-01 06:04:39.000000','2026-04-01 06:04:39.000000','ab207c872d9011f1bd099a17be7a306d','activated','2024-05-01 09:00:00.000000',NULL,'test-multi-carol@example.com',32,'c3333333333333333333333333333333','ab207ccb2d9011f1bd099a17be7a306d',NULL,NULL,NULL,0,NULL),
  -- dave: Data Science
  ('2026-04-01 06:04:52.000000','2026-04-01 06:04:52.000000','b2a157a12d9011f1bd099a17be7a306d','activated','2023-01-01 09:00:00.000000',NULL,'test-multi-dave@example.com',33,'c4444444444444444444444444444444','b2a157e52d9011f1bd099a17be7a306d',NULL,NULL,NULL,0,NULL),
  -- dual users (2 licenses each)
  -- test-dual-analyst01 (35): DataScience + Leadership
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc05d7c31c911f193878e7bc1b0d8b1','activated','2024-01-15 09:00:00.000000',NULL,'test-dual-analyst01@example.com',35,'c4444444444444444444444444444444','afc05e0a31c911f193878e7bc1b0d8b1','2024-01-10 09:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc119b231c911f193878e7bc1b0d8b1','activated','2024-01-20 09:00:00.000000',NULL,'test-dual-analyst01@example.com',35,'c1111111111111111111111111111111','afc11a3c31c911f193878e7bc1b0d8b1','2024-01-10 09:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-engineer01 (36): Technical + Business
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc195b031c911f193878e7bc1b0d8b1','activated','2024-02-01 10:00:00.000000',NULL,'test-dual-engineer01@example.com',36,'c2222222222222222222222222222222','afc1961131c911f193878e7bc1b0d8b1','2024-01-25 10:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc1990b31c911f193878e7bc1b0d8b1','activated','2024-02-05 10:00:00.000000',NULL,'test-dual-engineer01@example.com',36,'c5555555555555555555555555555555','afc1993631c911f193878e7bc1b0d8b1','2024-01-25 10:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-manager01 (37): Leadership + Compliance
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc228dc31c911f193878e7bc1b0d8b1','activated','2024-02-10 11:00:00.000000',NULL,'test-dual-manager01@example.com',37,'c1111111111111111111111111111111','afc2293d31c911f193878e7bc1b0d8b1','2024-02-05 11:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc22bb331c911f193878e7bc1b0d8b1','activated','2024-02-15 11:00:00.000000',NULL,'test-dual-manager01@example.com',37,'c3333333333333333333333333333333','afc22bd831c911f193878e7bc1b0d8b1','2024-02-05 11:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-bizanalyst01 (38): DataScience + Business
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc49f1131c911f193878e7bc1b0d8b1','activated','2024-03-01 09:30:00.000000',NULL,'test-dual-bizanalyst01@example.com',38,'c4444444444444444444444444444444','afc49f9331c911f193878e7bc1b0d8b1','2024-02-25 09:30:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc4a29e31c911f193878e7bc1b0d8b1','activated','2024-03-05 09:30:00.000000',NULL,'test-dual-bizanalyst01@example.com',38,'c5555555555555555555555555555555','afc4a2cf31c911f193878e7bc1b0d8b1','2024-02-25 09:30:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-itpro01 (39): Technical + Compliance
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc4e8e431c911f193878e7bc1b0d8b1','activated','2024-03-10 14:00:00.000000',NULL,'test-dual-itpro01@example.com',39,'c2222222222222222222222222222222','afc4e92b31c911f193878e7bc1b0d8b1','2024-03-05 14:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc4eb2231c911f193878e7bc1b0d8b1','activated','2024-03-15 14:00:00.000000',NULL,'test-dual-itpro01@example.com',39,'c3333333333333333333333333333333','afc4eb4531c911f193878e7bc1b0d8b1','2024-03-05 14:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-exec01 (40): Leadership + Business
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc5307b31c911f193878e7bc1b0d8b1','activated','2024-04-01 10:00:00.000000',NULL,'test-dual-exec01@example.com',40,'c1111111111111111111111111111111','afc530c331c911f193878e7bc1b0d8b1','2024-03-25 10:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc532aa31c911f193878e7bc1b0d8b1','activated','2024-04-01 10:00:00.000000',NULL,'test-dual-exec01@example.com',40,'c5555555555555555555555555555555','afc532ce31c911f193878e7bc1b0d8b1','2024-03-25 10:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-mlengineer01 (41): DataScience + Technical
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc5971331c911f193878e7bc1b0d8b1','activated','2024-04-15 11:30:00.000000',NULL,'test-dual-mlengineer01@example.com',41,'c4444444444444444444444444444444','afc5975a31c911f193878e7bc1b0d8b1','2024-04-10 11:30:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc5992c31c911f193878e7bc1b0d8b1','activated','2024-04-15 11:30:00.000000',NULL,'test-dual-mlengineer01@example.com',41,'c2222222222222222222222222222222','afc5994f31c911f193878e7bc1b0d8b1','2024-04-10 11:30:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-compliance01 (42): Compliance + Business
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc5d6a731c911f193878e7bc1b0d8b1','activated','2024-05-01 09:00:00.000000',NULL,'test-dual-compliance01@example.com',42,'c3333333333333333333333333333333','afc5d6f031c911f193878e7bc1b0d8b1','2024-04-25 09:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc5d8c931c911f193878e7bc1b0d8b1','activated','2024-05-05 09:00:00.000000',NULL,'test-dual-compliance01@example.com',42,'c5555555555555555555555555555555','afc5d8eb31c911f193878e7bc1b0d8b1','2024-04-25 09:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-techlead01 (43): Leadership + Technical
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc63a2731c911f193878e7bc1b0d8b1','activated','2024-05-15 13:00:00.000000',NULL,'test-dual-techlead01@example.com',43,'c1111111111111111111111111111111','afc63a7531c911f193878e7bc1b0d8b1','2024-05-10 13:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc63c5c31c911f193878e7bc1b0d8b1','activated','2024-05-20 13:00:00.000000',NULL,'test-dual-techlead01@example.com',43,'c2222222222222222222222222222222','afc63c7c31c911f193878e7bc1b0d8b1','2024-05-10 13:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-datascientist01 (44): DataScience + Compliance
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc680ad31c911f193878e7bc1b0d8b1','activated','2024-06-01 10:30:00.000000',NULL,'test-dual-datascientist01@example.com',44,'c4444444444444444444444444444444','afc680f331c911f193878e7bc1b0d8b1','2024-05-25 10:30:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc682c831c911f193878e7bc1b0d8b1','activated','2024-06-05 10:30:00.000000',NULL,'test-dual-datascientist01@example.com',44,'c3333333333333333333333333333333','afc682e831c911f193878e7bc1b0d8b1','2024-05-25 10:30:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-dataleader01 (45): Leadership + DataScience
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc6de2e31c911f193878e7bc1b0d8b1','activated','2024-06-15 11:00:00.000000',NULL,'test-dual-dataleader01@example.com',45,'c1111111111111111111111111111111','afc6de7c31c911f193878e7bc1b0d8b1','2024-06-10 11:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc6e06631c911f193878e7bc1b0d8b1','activated','2024-06-20 11:00:00.000000',NULL,'test-dual-dataleader01@example.com',45,'c4444444444444444444444444444444','afc6e08931c911f193878e7bc1b0d8b1','2024-06-10 11:00:00.000000',NULL,NULL,NULL,NULL),
  -- test-dual-producteng01 (46): Technical + Business
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc7328f31c911f193878e7bc1b0d8b1','activated','2024-07-01 09:00:00.000000',NULL,'test-dual-producteng01@example.com',46,'c2222222222222222222222222222222','afc732d831c911f193878e7bc1b0d8b1','2024-06-25 09:00:00.000000',NULL,NULL,NULL,NULL),
  ('2026-04-06 15:02:53.000000','2026-04-06 15:02:53.000000','afc734c531c911f193878e7bc1b0d8b1','activated','2024-07-05 09:00:00.000000',NULL,'test-dual-producteng01@example.com',46,'c5555555555555555555555555555555','afc734e831c911f193878e7bc1b0d8b1','2024-06-25 09:00:00.000000',NULL,NULL,NULL,NULL);

-- -----------------------------------------------------------------------------
-- License Manager Role Assignments
-- role_id=2 → subscriptions_learner
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `subscriptions_subscriptionsroleassignment`
  (`id`, `created`, `modified`, `enterprise_customer_uuid`, `role_id`,
   `user_id`, `applies_to_all_contexts`)
VALUES
  (1,'2026-03-30 05:34:07.604560','2026-03-30 05:34:07.604560','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,2, 0),
  (2,'2026-03-30 05:34:07.612708','2026-03-30 05:34:07.612708','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,4, 0),
  (3,'2026-03-30 05:34:07.640605','2026-03-30 05:34:07.640605','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,5, 0),
  (4,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,9, 0),
  (5,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,10,0),
  (6,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,11,0),
  (7,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,12,0),
  (8,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,13,0),
  (9,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,14,0),
  (10,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,15,0),
  (11,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,16,0),
  (12,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,17,0),
  (13,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,18,0),
  (14,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,19,0),
  (15,'2026-04-06 16:57:27.000000','2026-04-06 16:57:27.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,20,0);
-- NOTE: user_id values 2-20 above are license_manager.core_user IDs,
-- which differ from edxapp auth_user IDs. See enterprise_access.core_user
-- for the user mapping (lms_user_id field).


-- =============================================================================
-- DATABASE: enterprise_catalog
-- =============================================================================
USE enterprise_catalog;

-- -----------------------------------------------------------------------------
-- Catalog Queries (5 simple course-type queries for multi-license catalogs)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `catalog_catalogquery`
  (`id`, `content_filter`, `content_filter_hash`, `created`, `modified`, `uuid`, `title`)
VALUES
  (4,'{"content_type": "course"}',NULL,'2026-03-27 11:29:00.000000','2026-03-31 10:18:42.000000','11111111111111111111111111111111',NULL),
  (5,'{"content_type": "course"}',NULL,'2026-03-27 11:29:00.000000','2026-03-31 10:18:42.000000','22222222222222222222222222222222',NULL),
  (6,'{"content_type": "course"}',NULL,'2026-03-27 11:29:00.000000','2026-03-31 10:18:42.000000','33333333333333333333333333333333',NULL),
  (7,'{"content_type": "course"}',NULL,'2026-03-27 11:29:00.000000','2026-03-31 10:18:42.000000','44444444444444444444444444444444',NULL),
  (8,'{"content_type": "course"}',NULL,'2026-03-27 11:29:00.000000','2026-03-31 10:18:42.000000','55555555555555555555555555555555',NULL);

-- -----------------------------------------------------------------------------
-- Enterprise Catalogs (5 catalogs for test-multi-enterprise)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `catalog_enterprisecatalog`
  (`created`, `modified`, `uuid`, `enterprise_uuid`, `catalog_query_id`,
   `enabled_course_modes`, `publish_audit_enrollment_urls`, `title`, `enterprise_name`)
VALUES
  ('2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000',
   '11111111111111111111111111111111','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',4,
   '["verified", "professional", "audit"]',1,'Leadership Training Catalog','Test Multi-License Enterprise'),
  ('2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000',
   '22222222222222222222222222222222','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',5,
   '["verified", "professional", "audit"]',1,'Technical Skills Catalog','Test Multi-License Enterprise'),
  ('2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000',
   '33333333333333333333333333333333','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',6,
   '["verified", "professional", "audit"]',1,'Compliance Training Catalog','Test Multi-License Enterprise'),
  ('2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000',
   '44444444444444444444444444444444','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',7,
   '["verified", "professional", "audit"]',1,'Data Science Catalog','Test Multi-License Enterprise'),
  ('2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000',
   '55555555555555555555555555555555','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',8,
   '["verified", "professional", "audit"]',1,'Business & Strategy Catalog','Test Multi-License Enterprise');

-- -----------------------------------------------------------------------------
-- Content Metadata (courses assigned to catalogs)
-- These are the test courses used in ENT-11683 testing
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `catalog_contentmetadata`
  (`id`, `created`, `modified`, `content_key`, `content_type`,
   `parent_content_key`, `json_metadata`, `content_uuid`)
VALUES
  -- Existing edX courses (used in original devstack setup)
  (24,'2026-03-27 11:34:41.000000','2026-03-31 07:45:08.000000','edX+DemoX','course',NULL,
   '{"key": "edX+DemoX", "title": "Demonstration Course", "content_type": "course"}',
   'd0000000000000000000000000000001'),
  (31,'2026-03-31 06:48:26.000000','2026-03-31 07:45:08.000000','SONATA+123','course',NULL,
   '{"key": "SONATA+123", "title": "Python datascience", "content_type": "course"}',
   'a2222222222222222222222222222222'),
  -- Leadership Catalog courses
  (55,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+LEADER101+2024','course',NULL,
   '{"key": "course-v1:TestOrg+LEADER101+2024", "title": "Strategic Leadership Fundamentals", "course_type": "verified", "content_type": "course"}',
   'c0000001000000000000000000000001'),
  (56,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+LEADER201+2024','course',NULL,
   '{"key": "course-v1:TestOrg+LEADER201+2024", "title": "Executive Decision Making", "course_type": "verified", "content_type": "course"}',
   'c0000001000000000000000000000002'),
  -- Technical Catalog courses
  (57,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+TECH101+2024','course',NULL,
   '{"key": "course-v1:TestOrg+TECH101+2024", "title": "Introduction to Python Programming", "course_type": "verified", "content_type": "course"}',
   'c0000002000000000000000000000001'),
  (58,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+TECH201+2024','course',NULL,
   '{"key": "course-v1:TestOrg+TECH201+2024", "title": "Advanced Software Engineering", "course_type": "verified", "content_type": "course"}',
   'c0000002000000000000000000000002'),
  -- Compliance Catalog course
  (59,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+COMP101+2024','course',NULL,
   '{"key": "course-v1:TestOrg+COMP101+2024", "title": "Data Privacy and GDPR", "course_type": "verified", "content_type": "course"}',
   'c0000003000000000000000000000001'),
  -- Data Science Catalog courses (SONATA+123 is also here)
  (60,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+DS101+2024','course',NULL,
   '{"key": "course-v1:TestOrg+DS101+2024", "title": "Data Science with Python", "course_type": "verified", "content_type": "course"}',
   'c0000004000000000000000000000001'),
  (61,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+DS201+2024','course',NULL,
   '{"key": "course-v1:TestOrg+DS201+2024", "title": "Machine Learning Fundamentals", "course_type": "verified", "content_type": "course"}',
   'c0000004000000000000000000000002'),
  -- Business Catalog course
  (62,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+BUS101+2024','course',NULL,
   '{"key": "course-v1:TestOrg+BUS101+2024", "title": "Business Strategy Essentials", "course_type": "verified", "content_type": "course"}',
   'c0000005000000000000000000000001'),
  -- Cross-catalog course (appears in multiple catalogs)
  (63,'2026-03-31 10:18:42.000000','2026-03-31 10:18:42.000000','course-v1:TestOrg+MULTI101+2024','course',NULL,
   '{"key": "course-v1:TestOrg+MULTI101+2024", "title": "Tech Leadership: Managing Engineering Teams", "course_type": "verified", "content_type": "course"}',
   'c0000000000000000000000000000001');

-- -----------------------------------------------------------------------------
-- Content → Catalog Query Associations
-- (which courses appear in which catalog queries)
-- catalog_query_id 4=Leadership, 5=Technical, 6=Compliance, 7=DataScience, 8=Business
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `catalog_contentmetadata_catalog_queries`
  (`id`, `contentmetadata_id`, `catalogquery_id`)
VALUES
  -- edX+DemoX → Technical(5), Compliance(6)
  (113,24,4),
  (116,24,5),
  (119,24,6),
  -- SONATA+123 → Technical(5)
  (117,31,5),
  -- Leadership courses → Leadership(4)
  (200,55,4),(201,56,4),
  -- Technical courses → Technical(5)
  (202,57,5),(203,58,5),
  -- Compliance → Compliance(6)
  (204,59,6),
  -- DataScience → DataScience(7)
  (205,60,7),(206,61,7),
  -- SONATA+123 → DataScience(7) as well
  (207,31,7),
  -- Business → Business(8)
  (208,62,8),
  -- Multi-catalog course → Leadership(4) + Technical(5)
  (209,63,4),(210,63,5);

-- -----------------------------------------------------------------------------
-- Enterprise Catalog Role Assignments (enterprise_catalog)
-- role_id=2 → enterprise_catalog_learner
-- user_id values here are enterprise_catalog.core_user IDs
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `catalog_enterprisecatalogroleassignment`
  (`id`, `created`, `modified`, `enterprise_id`, `role_id`, `user_id`, `applies_to_all_contexts`)
VALUES
  (1,'2026-03-30 08:22:14.598778','2026-03-30 08:22:14.598778','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,4,0),
  (2,'2026-03-30 08:22:14.603279','2026-03-30 08:22:14.603279','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,6,0),
  (3,'2026-03-30 08:22:14.606770','2026-03-30 08:22:14.606770','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,8,0),
  (4,'2026-03-30 08:22:14.610312','2026-03-30 08:22:14.610312','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,10,0),
  (5,'2026-03-30 08:22:14.613644','2026-03-30 08:22:14.613644','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,11,0),
  (6,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,13,0),
  (7,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,15,0),
  (8,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,16,0),
  (9,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,17,0),
  (10,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,18,0),
  (11,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,19,0),
  (12,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,20,0),
  (13,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,21,0),
  (14,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,22,0),
  (15,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,23,0),
  (16,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,24,0),
  (17,'2026-04-06 17:09:59.000000','2026-04-06 17:09:59.000000','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,25,0);


-- =============================================================================
-- DATABASE: enterprise_access
-- =============================================================================
USE enterprise_access;

-- -----------------------------------------------------------------------------
-- Users (mirror of relevant edxapp users — lms_user_id = edxapp auth_user.id)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `core_user`
  (`id`, `password`, `last_login`, `is_superuser`, `username`, `first_name`,
   `last_name`, `email`, `is_staff`, `is_active`, `date_joined`,
   `full_name`, `lms_user_id`)
VALUES
  (1,'pbkdf2_sha256$1000000$23MNC6t1l9rDU7Lfwjz9ac$6MeK2RiNFzgqyQDIP+Qt4QLqyUE5cEhyxLTMqarq6TA=',
   '2026-04-06 08:08:59.073847',1,'edx','','','edx@example.com',1,1,'2026-02-14 15:44:45.585543',NULL,3),
  (2,'',NULL,0,'test-multi-alice','','','test-multi-alice@example.com',0,1,'2026-03-27 11:11:09.234508',NULL,30),
  (3,'',NULL,0,'test-multi-bob','','','test-multi-bob@example.com',0,1,'2026-03-30 07:22:14.952460',NULL,31),
  (4,'',NULL,0,'test-multi-carol','','','test-multi-carol@example.com',0,1,'2026-03-30 07:30:38.348288',NULL,32),
  (5,'',NULL,0,'test-multi-dave','','','test-multi-dave@example.com',0,1,'2026-03-30 07:42:00.595855',NULL,33),
  (6,'',NULL,0,'test-multi-eve','','','test-multi-eve@example.com',0,1,'2026-03-30 07:42:54.360883',NULL,34),
  (7,'',NULL,0,'test-dual-analyst01','','','test-dual-analyst01@example.com',0,1,'2026-04-06 16:19:22.848913',NULL,35),
  (8,'',NULL,0,'test-dual-datascientist01','','','test-dual-datascientist01@example.com',0,1,'2026-04-06 16:38:34.842051',NULL,NULL),
  (9,'',NULL,0,'test-dual-engineer01','','','test-dual-engineer01@example.com',0,1,'2026-04-06 16:38:34.849479',NULL,NULL),
  (10,'',NULL,0,'test-dual-manager01','','','test-dual-manager01@example.com',0,1,'2026-04-06 16:38:34.856303',NULL,37),
  (11,'',NULL,0,'test-dual-bizanalyst01','','','test-dual-bizanalyst01@example.com',0,1,'2026-04-06 16:38:34.863375',NULL,38),
  (12,'',NULL,0,'test-dual-itpro01','','','test-dual-itpro01@example.com',0,1,'2026-04-06 16:38:34.870590',NULL,NULL),
  (13,'',NULL,0,'test-dual-exec01','','','test-dual-exec01@example.com',0,1,'2026-04-06 16:38:34.877219',NULL,NULL),
  (14,'',NULL,0,'test-dual-mlengineer01','','','test-dual-mlengineer01@example.com',0,1,'2026-04-06 16:38:34.884863',NULL,NULL),
  (15,'',NULL,0,'test-dual-compliance01','','','test-dual-compliance01@example.com',0,1,'2026-04-06 16:38:34.892060',NULL,NULL),
  (16,'',NULL,0,'test-dual-techlead01','','','test-dual-techlead01@example.com',0,1,'2026-04-06 16:38:34.899153',NULL,43),
  (17,'',NULL,0,'test-dual-dataleader01','','','test-dual-dataleader01@example.com',0,1,'2026-04-06 16:38:34.905965',NULL,NULL),
  (18,'',NULL,0,'test-dual-producteng01','','','test-dual-producteng01@example.com',0,1,'2026-04-06 16:38:34.912091',NULL,NULL);

-- -----------------------------------------------------------------------------
-- Feature Roles
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `core_enterpriseaccessfeaturerole`
  (`id`, `created`, `modified`, `name`, `description`)
VALUES
  (1,'2026-02-14 15:42:25.081952','2026-02-14 15:42:25.081952','enterprise_access_requests_admin',NULL),
  (2,'2026-02-14 15:42:25.084172','2026-02-14 15:42:25.084172','enterprise_access_requests_learner',NULL),
  (3,'2026-03-30 05:02:36.126457','2026-03-30 05:02:36.126457','enterprise_access_bff_learner',NULL),
  (4,'2026-04-07 06:33:33.000000','2026-04-07 06:33:33.000000','enterprise_access_subsidy_access_policy_learner',
   'Explicit learner access to subsidy access policy endpoints');

-- -----------------------------------------------------------------------------
-- Role Assignments
-- role 2 = requests_learner  (needed for Browse & Request / fetchBrowseAndRequestConfiguration)
-- role 3 = bff_learner        (needed for BFF endpoint)
-- role 4 = subsidy_access_policy_learner (needed for /credits_available/)
-- user_id values here are enterprise_access.core_user IDs (not edxapp IDs)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `core_enterpriseaccessroleassignment`
  (`id`, `created`, `modified`, `applies_to_all_contexts`,
   `enterprise_customer_uuid`, `role_id`, `user_id`)
VALUES
  -- bff_learner (role 3) for all test users
  (1,'2026-03-30 05:02:36.133565','2026-03-30 05:02:36.133565',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,2),
  (2,'2026-04-06 16:38:34.837017','2026-04-06 16:38:34.837017',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,7),
  (3,'2026-04-06 16:38:34.845913','2026-04-06 16:38:34.845913',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,8),
  (4,'2026-04-06 16:38:34.853308','2026-04-06 16:38:34.853308',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,9),
  (5,'2026-04-06 16:38:34.860128','2026-04-06 16:38:34.860128',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,10),
  (6,'2026-04-06 16:38:34.867448','2026-04-06 16:38:34.867448',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,11),
  (7,'2026-04-06 16:38:34.874168','2026-04-06 16:38:34.874168',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,12),
  (8,'2026-04-06 16:38:34.881115','2026-04-06 16:38:34.881115',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,13),
  (9,'2026-04-06 16:38:34.888950','2026-04-06 16:38:34.888950',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,14),
  (10,'2026-04-06 16:38:34.895931','2026-04-06 16:38:34.895931',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,15),
  (11,'2026-04-06 16:38:34.902814','2026-04-06 16:38:34.902814',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,16),
  (12,'2026-04-06 16:38:34.909238','2026-04-06 16:38:34.909238',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,17),
  (13,'2026-04-06 16:38:34.915186','2026-04-06 16:38:34.915186',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',3,18),
  -- requests_learner (role 2) for analyst01 only (needed for B&R config fetch)
  (14,'2026-04-07 05:11:03.000000','2026-04-07 05:11:03.000000',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2,7),
  -- subsidy_access_policy_learner (role 4) for analyst01 (fixes 403 on /credits_available/)
  (15,'2026-04-07 06:33:43.000000','2026-04-07 06:33:43.000000',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',4,7);

-- NOTE: To grant role 4 (subsidy_access_policy_learner) to ALL dual users, run:
-- INSERT IGNORE INTO core_enterpriseaccessroleassignment
--   (created, modified, applies_to_all_contexts, enterprise_customer_uuid, role_id, user_id)
-- SELECT NOW(), NOW(), 0, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 4, id
-- FROM core_user
-- WHERE username LIKE 'test-dual-%'
--   AND id NOT IN (
--     SELECT user_id FROM core_enterpriseaccessroleassignment
--     WHERE role_id=4 AND enterprise_customer_uuid='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
--   );

-- -----------------------------------------------------------------------------
-- Browse & Request Customer Configuration
-- (enables the B&R flow for test-multi-enterprise)
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `subsidy_request_subsidyrequestcustomerconfiguration`
  (`created`, `modified`, `enterprise_customer_uuid`,
   `subsidy_requests_enabled`, `subsidy_type`, `changed_by_id`, `last_remind_date`)
VALUES
  ('2026-04-07 05:01:10.000000','2026-04-07 05:01:10.000000',
   'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',1,'License',NULL,NULL);


-- =============================================================================
-- Re-enable foreign key checks
-- =============================================================================
SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
-- 1. Run against a fresh devstack that has completed migrations for all services.
-- 2. The edxapp auth_user passwords are real hashed values; users can log in
--    with whatever password they were created with in the source environment.
--    Reset passwords via LMS admin if needed: /admin/auth/user/
-- 3. The license_manager / enterprise_catalog / enterprise_access core_user
--    tables are populated by those services' authentication middleware on first
--    login — the INSERT IGNORE rows here pre-seed them so role assignments work
--    before first login.
-- 4. The `subscriptions_license.subscription_plan_id` column references
--    subscriptions_subscriptionplan.uuid (char32), not an integer PK.
-- 5. After importing, restart enterprise-access and enterprise-catalog workers
--    so their caches pick up the new catalog/subscription data.
