import React, { useState } from 'react';
import { Alert, StyleSheet, View, TextInput, Button, Text, TouchableOpacity, ActivityIndicator } from 'react-native';
import { supabase } from '../lib/supabase';

export default function Auth() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [role, setRole] = useState<'client' | 'provider'>('client');
  const [loading, setLoading] = useState(false);
  const [isLogin, setIsLogin] = useState(true);

  async function signInWithEmail() {
    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({
      email: email,
      password: password,
    });

    if (error) Alert.alert('Erro no Login', error.message);
    setLoading(false);
  }

  async function signUpWithEmail() {
    setLoading(true);
    
    // 1. Cria o usuário no Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email: email,
      password: password,
    });

    if (authError) {
      Alert.alert('Erro no Cadastro', authError.message);
      setLoading(false);
      return;
    }

    // 2. Se deu certo, cria o perfil na nossa tabela
    if (authData.user) {
      const { error: profileError } = await supabase.from('profiles').insert([
        {
          id: authData.user.id,
          full_name: fullName || 'Usuário',
          role: role,
        }
      ]);

      if (profileError) {
        Alert.alert('Erro ao criar perfil', profileError.message);
      } else {
        Alert.alert('Sucesso!', 'Conta criada com sucesso. Verifique seu email se necessário.');
      }
    }
    setLoading(false);
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Desperrengue</Text>
      
      {!isLogin && (
        <View style={styles.roleContainer}>
          <TouchableOpacity 
            style={[styles.roleBtn, role === 'client' && styles.roleActive]} 
            onPress={() => setRole('client')}
          >
            <Text style={role === 'client' ? styles.roleTextActive : styles.roleText}>Sou Cliente</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            style={[styles.roleBtn, role === 'provider' && styles.roleActive]} 
            onPress={() => setRole('provider')}
          >
            <Text style={role === 'provider' ? styles.roleTextActive : styles.roleText}>Sou Profissional</Text>
          </TouchableOpacity>
        </View>
      )}

      {!isLogin && (
        <TextInput
          style={styles.input}
          onChangeText={(text) => setFullName(text)}
          value={fullName}
          placeholder="Nome Completo"
          autoCapitalize="words"
        />
      )}

      <TextInput
        style={styles.input}
        onChangeText={(text) => setEmail(text)}
        value={email}
        placeholder="Email"
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <TextInput
        style={styles.input}
        onChangeText={(text) => setPassword(text)}
        value={password}
        secureTextEntry={true}
        placeholder="Senha"
        autoCapitalize="none"
      />
      
      <View style={[styles.verticallySpaced, styles.mt20]}>
        <Button 
          title={isLogin ? "Entrar" : "Criar Conta"} 
          disabled={loading} 
          onPress={isLogin ? signInWithEmail : signUpWithEmail} 
        />
      </View>

      <TouchableOpacity onPress={() => setIsLogin(!isLogin)} style={styles.mt20}>
        <Text style={styles.switchText}>
          {isLogin ? "Não tem conta? Cadastre-se" : "Já tem conta? Faça Login"}
        </Text>
      </TouchableOpacity>
      
      {loading && <ActivityIndicator size="large" style={{ marginTop: 20 }} />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { marginTop: 40, padding: 12, flex: 1, justifyContent: 'center' },
  title: { fontSize: 32, fontWeight: 'bold', textAlign: 'center', marginBottom: 40, color: '#2563eb' },
  verticallySpaced: { paddingTop: 4, paddingBottom: 4, alignSelf: 'stretch' },
  mt20: { marginTop: 20 },
  input: { borderWidth: 1, borderColor: '#ccc', padding: 12, marginBottom: 15, borderRadius: 8, backgroundColor: '#fff' },
  switchText: { textAlign: 'center', color: '#2563eb', fontWeight: 'bold' },
  roleContainer: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 },
  roleBtn: { flex: 1, padding: 10, borderWidth: 1, borderColor: '#2563eb', marginHorizontal: 5, borderRadius: 8, alignItems: 'center' },
  roleActive: { backgroundColor: '#2563eb' },
  roleText: { color: '#2563eb', fontWeight: 'bold' },
  roleTextActive: { color: '#fff', fontWeight: 'bold' }
});
