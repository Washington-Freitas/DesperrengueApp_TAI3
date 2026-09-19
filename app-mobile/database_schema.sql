-- Tabela de Perfis (Estende os usuários autenticados)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  role TEXT CHECK (role IN ('client', 'provider', 'admin')) NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  verification_status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Tabela de Demandas (Jobs)
CREATE TABLE public.jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  client_id UUID REFERENCES public.profiles(id) NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'completed', 'canceled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Tabela de Orçamentos (Quotes)
CREATE TABLE public.quotes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE NOT NULL,
  provider_id UUID REFERENCES public.profiles(id) NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  message TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Configuração básica de Segurança (RLS - Row Level Security)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança temporárias para o MVP (Acesso total para usuários logados)
CREATE POLICY "Permitir leitura para todos os usuários logados" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Permitir inserção pelo próprio usuário" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Permitir leitura de jobs" ON public.jobs FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Permitir criação de jobs" ON public.jobs FOR INSERT WITH CHECK (auth.uid() = client_id);
CREATE POLICY "Permitir leitura de quotes" ON public.quotes FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Permitir criação de quotes" ON public.quotes FOR INSERT WITH CHECK (auth.uid() = provider_id);
