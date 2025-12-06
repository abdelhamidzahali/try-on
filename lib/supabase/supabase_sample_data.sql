-- Helper function to insert users into auth.users table
CREATE OR REPLACE FUNCTION insert_user_to_auth(
    email text,
    password text
) RETURNS UUID AS $$
DECLARE
  user_id uuid;
  encrypted_pw text;
BEGIN
  user_id := gen_random_uuid();
  encrypted_pw := crypt(password, gen_salt('bf'));
  
  INSERT INTO auth.users
    (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES
    (gen_random_uuid(), user_id, 'authenticated', 'authenticated', email, encrypted_pw, '2023-05-03 19:41:43.585805+00', '2023-04-22 13:10:03.275387+00', '2023-04-22 13:10:31.458239+00', '{"provider":"email","providers":["email"]}', '{}', '2023-05-03 19:41:43.580424+00', '2023-05-03 19:41:43.585948+00', '', '', '', '');
  
  INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  VALUES
    (gen_random_uuid(), user_id, format('{"sub":"%s","email":"%s"}', user_id::text, email)::jsonb, 'email', '2023-05-03 19:41:43.582456+00', '2023-05-03 19:41:43.582497+00', '2023-05-03 19:41:43.582497+00');
  
  RETURN user_id;
END;
$$ LANGUAGE plpgsql;

-- Insert sample data into users table
INSERT INTO users (id, name, email, profile_image_path)
SELECT insert_user_to_auth('alice@example.com', 'password123'), 'Alice Smith', 'alice@example.com', 'profiles/alice_profile.jpg'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'alice@example.com');

INSERT INTO users (id, name, email, profile_image_path)
SELECT insert_user_to_auth('bob@example.com', 'securepass'), 'Bob Johnson', 'bob@example.com', 'profiles/bob_profile.jpg'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'bob@example.com');

INSERT INTO users (id, name, email, profile_image_path)
SELECT insert_user_to_auth('charlie@example.com', 'mysecret'), 'Charlie Brown', 'charlie@example.com', 'profiles/charlie_profile.jpg'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'charlie@example.com');

-- Insert sample data into clothing_items table
INSERT INTO clothing_items (user_id, name, category, brand, color, image_path, description)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'Blue Denim Jacket',
  'Jacket',
  'Levi''s',
  'Blue',
  'clothing/alice/denim_jacket.jpg',
  'Classic blue denim jacket, perfect for casual wear.'
WHERE NOT EXISTS (SELECT 1 FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Blue Denim Jacket');

INSERT INTO clothing_items (user_id, name, category, brand, color, image_path, description)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'White T-Shirt',
  'T-Shirt',
  'Hanes',
  'White',
  'clothing/alice/white_tshirt.jpg',
  'Basic white cotton t-shirt.'
WHERE NOT EXISTS (SELECT 1 FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'White T-Shirt');

INSERT INTO clothing_items (user_id, name, category, brand, color, image_path, description)
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'Black Leather Jacket',
  'Jacket',
  'Zara',
  'Black',
  'clothing/bob/leather_jacket.jpg',
  'Stylish black leather jacket.'
WHERE NOT EXISTS (SELECT 1 FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Black Leather Jacket');

INSERT INTO clothing_items (user_id, name, category, brand, color, image_path, description)
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'Grey Hoodie',
  'Hoodie',
  'Nike',
  'Grey',
  'clothing/bob/grey_hoodie.jpg',
  'Comfortable grey hoodie with front pocket.'
WHERE NOT EXISTS (SELECT 1 FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Grey Hoodie');

INSERT INTO clothing_items (user_id, name, category, brand, color, image_path, description)
SELECT
  (SELECT id FROM users WHERE email = 'charlie@example.com'),
  'Red Dress',
  'Dress',
  'H&M',
  'Red',
  'clothing/charlie/red_dress.jpg',
  'Elegant red evening dress.'
WHERE NOT EXISTS (SELECT 1 FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com') AND name = 'Red Dress');

-- Insert sample data into generated_images table
INSERT INTO generated_images (user_id, image_path, prompt)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'generated/alice/tryon_denim_tshirt.jpg',
  'Alice wearing a blue denim jacket over a white t-shirt.'
WHERE NOT EXISTS (SELECT 1 FROM generated_images WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND image_path = 'generated/alice/tryon_denim_tshirt.jpg');

INSERT INTO generated_images (user_id, image_path, prompt)
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'generated/bob/tryon_leather_hoodie.jpg',
  'Bob wearing a black leather jacket over a grey hoodie.'
WHERE NOT EXISTS (SELECT 1 FROM generated_images WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND image_path = 'generated/bob/tryon_leather_hoodie.jpg');

INSERT INTO generated_images (user_id, image_path, prompt)
SELECT
  (SELECT id FROM users WHERE email = 'charlie@example.com'),
  'generated/charlie/tryon_red_dress.jpg',
  'Charlie wearing a red dress in a garden setting.'
WHERE NOT EXISTS (SELECT 1 FROM generated_images WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com') AND image_path = 'generated/charlie/tryon_red_dress.jpg');

-- Insert sample data into tryon_sessions table
INSERT INTO tryon_sessions (user_id, user_photo_path, clothing_id, clothing_photo_path, status, result_id)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'user_photos/alice/alice_pose1.jpg',
  (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Blue Denim Jacket'),
  'clothing/alice/denim_jacket.jpg',
  'completed',
  (SELECT id FROM generated_images WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND image_path = 'generated/alice/tryon_denim_tshirt.jpg')
WHERE NOT EXISTS (
  SELECT 1 FROM tryon_sessions
  WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com')
  AND user_photo_path = 'user_photos/alice/alice_pose1.jpg'
  AND clothing_id = (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Blue Denim Jacket')
);

INSERT INTO tryon_sessions (user_id, user_photo_path, clothing_id, clothing_photo_path, status, result_id)
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'user_photos/bob/bob_pose1.jpg',
  (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Black Leather Jacket'),
  'clothing/bob/leather_jacket.jpg',
  'completed',
  (SELECT id FROM generated_images WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND image_path = 'generated/bob/tryon_leather_hoodie.jpg')
WHERE NOT EXISTS (
  SELECT 1 FROM tryon_sessions
  WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com')
  AND user_photo_path = 'user_photos/bob/bob_pose1.jpg'
  AND clothing_id = (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Black Leather Jacket')
);

INSERT INTO tryon_sessions (user_id, user_photo_path, clothing_id, clothing_photo_path, status, result_id)
SELECT
  (SELECT id FROM users WHERE email = 'charlie@example.com'),
  'user_photos/charlie/charlie_pose1.jpg',
  (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com') AND name = 'Red Dress'),
  'clothing/charlie/red_dress.jpg',
  'completed',
  (SELECT id FROM generated_images WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com') AND image_path = 'generated/charlie/tryon_red_dress.jpg')
WHERE NOT EXISTS (
  SELECT 1 FROM tryon_sessions
  WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com')
  AND user_photo_path = 'user_photos/charlie/charlie_pose1.jpg'
  AND clothing_id = (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com') AND name = 'Red Dress')
);

INSERT INTO tryon_sessions (user_id, user_photo_path, clothing_id, clothing_photo_path, status)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'user_photos/alice/alice_pose2.jpg',
  (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'White T-Shirt'),
  'clothing/alice/white_tshirt.jpg',
  'pending'
WHERE NOT EXISTS (
  SELECT 1 FROM tryon_sessions
  WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com')
  AND user_photo_path = 'user_photos/alice/alice_pose2.jpg'
  AND clothing_id = (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'White T-Shirt')
);

INSERT INTO tryon_sessions (user_id, user_photo_path, clothing_id, clothing_photo_path, status, error_message)
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'user_photos/bob/bob_pose2.jpg',
  (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Grey Hoodie'),
  'clothing/bob/grey_hoodie.jpg',
  'failed',
  'Image processing error: face not detected.'
WHERE NOT EXISTS (
  SELECT 1 FROM tryon_sessions
  WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com')
  AND user_photo_path = 'user_photos/bob/bob_pose2.jpg'
  AND clothing_id = (SELECT id FROM clothing_items WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Grey Hoodie')
);