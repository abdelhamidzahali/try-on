-- Enable Row Level Security for all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE clothing_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE tryon_sessions ENABLE ROW LEVEL SECURITY;

-- Policies for users table
-- Allow users to read their own user record
CREATE POLICY "Users can view own user data" ON users
  FOR SELECT USING (auth.uid() = id);

-- Allow users to insert their own user record on signup
CREATE POLICY "Users can insert own user data" ON users
  FOR INSERT WITH CHECK (true);

-- Allow users to update their own user record
CREATE POLICY "Users can update own user data" ON users
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (true);

-- Policies for clothing_items table
-- Allow authenticated users to perform all operations on their clothing items
CREATE POLICY "Users can view own clothing items" ON clothing_items
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own clothing items" ON clothing_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own clothing items" ON clothing_items
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own clothing items" ON clothing_items
  FOR DELETE USING (auth.uid() = user_id);

-- Policies for generated_images table
-- Allow authenticated users to perform all operations on their generated images
CREATE POLICY "Users can view own generated images" ON generated_images
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own generated images" ON generated_images
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own generated images" ON generated_images
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own generated images" ON generated_images
  FOR DELETE USING (auth.uid() = user_id);

-- Policies for tryon_sessions table
-- Allow authenticated users to perform all operations on their try-on sessions
CREATE POLICY "Users can view own tryon sessions" ON tryon_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tryon sessions" ON tryon_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tryon sessions" ON tryon_sessions
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own tryon sessions" ON tryon_sessions
  FOR DELETE USING (auth.uid() = user_id);
