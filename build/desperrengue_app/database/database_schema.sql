-- ============================================================================
-- PLATAFORMA DESPERRENGUE - SCHEMA DE BASE DE DADOS (SUPABASE)
-- ============================================================================

-- Tabela de Perfis (Estende os usuários autenticados do auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  role TEXT CHECK (role IN ('client', 'provider', 'admin')) NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  verification_status TEXT DEFAULT 'pending',
  -- Novos campos de localização para o KYC (Know Your Customer)
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address_city TEXT,
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
  
  -- [NOVO] Estimativa de orçamento do cliente (opcional)
  budget_estimate DECIMAL(10, 2),
  
  -- [NOVO] Dados de geolocalização do local do serviço
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address_summary TEXT,
  
  -- [NOVO] Controlo de Pagamento
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'held_in_escrow', 'released', 'refunded')),
  
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

-- ============================================================================
-- CONFIGURAÇÃO DE SEGURANÇA AVANÇADA (Row Level Security - RLS)
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- Políticas para PERFIS (Profiles)
-- ----------------------------------------------------------------------------
-- Todos logados podem ver os perfis básicos uns dos outros (necessário para ver quem fez o quote)
CREATE POLICY "Leitura de perfis para usuários logados" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');
-- Apenas o próprio utilizador pode atualizar os seus dados
CREATE POLICY "Atualização do próprio perfil" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Criação do próprio perfil" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- Políticas para DEMANDAS (Jobs)
-- ----------------------------------------------------------------------------
-- Todos podem ver as demandas em estado 'open' (para os prestadores procurarem trabalho)
CREATE POLICY "Ver demandas abertas" ON public.jobs FOR SELECT USING (status = 'open' OR auth.uid() = client_id);
-- Apenas os clientes podem criar as suas próprias demandas
CREATE POLICY "Clientes criam as suas demandas" ON public.jobs FOR INSERT WITH CHECK (auth.uid() = client_id);
-- Apenas os clientes podem atualizar o estado (ex: cancelar) das suas demandas
CREATE POLICY "Clientes atualizam as suas demandas" ON public.jobs FOR UPDATE USING (auth.uid() = client_id);

-- ----------------------------------------------------------------------------
-- Políticas para ORÇAMENTOS (Quotes)
-- ----------------------------------------------------------------------------
-- O prestador vê os seus orçamentos E o cliente vê os orçamentos da sua demanda
CREATE POLICY "Leitura de orçamentos segura" ON public.quotes FOR SELECT USING (
  auth.uid() = provider_id 
  OR 
  auth.uid() IN (SELECT client_id FROM public.jobs WHERE id = job_id)
);
-- Apenas prestadores podem criar orçamentos
CREATE POLICY "Criação de orçamentos" ON public.quotes FOR INSERT WITH CHECK (auth.uid() = provider_id);