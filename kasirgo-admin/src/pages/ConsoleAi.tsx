import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Bot, Send, Plus, Trash2, Loader2, Sparkles, TerminalSquare, History, RefreshCw,
} from 'lucide-react';
import { supabase } from '../config/supabase';

type Session = { id: string; title: string | null; created_at: string; updated_at: string };
type Message = { role: string; content: string | null; tool_calls?: unknown; created_at?: string };
type ToolLog = { name: string; mode: string | null; sql: string; ok: boolean };

export function ConsoleAiPage() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [activeId, setActiveId] = useState('');
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  const loadSessions = useCallback(async () => {
    try {
      const { data, error } = await supabase.functions.invoke('system_console', { body: { action: 'list' } });
      if (error) throw error;
      setSessions((data as any)?.sessions ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat sesi');
    } finally {
      setLoading(false);
    }
  }, []);

  const loadHistory = useCallback(async (sessionId: string) => {
    if (!sessionId) return;
    try {
      const { data, error } = await supabase.functions.invoke('system_console', { body: { action: 'history', session_id: sessionId } });
      if (error) throw error;
      setMessages((data as any)?.messages ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat riwayat');
    }
  }, []);

  useEffect(() => { loadSessions(); }, [loadSessions]);
  useEffect(() => {
    if (activeId) loadHistory(activeId);
  }, [activeId, loadHistory]);
  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages]);

  const send = async () => {
    const text = input.trim();
    if (!text || busy) return;
    setInput('');
    setError(null);
    setBusy(true);
    setMessages((m) => [...m, { role: 'user', content: text }]);
    try {
      const { data, error } = await supabase.functions.invoke('system_console', {
        body: { action: 'chat', session_id: activeId, message: text },
      });
      if (error) throw error;
      const res = data as any;
      if (!res?.success) throw new Error(res?.message ?? 'Gagal memproses.');
      if (res.session_id && !activeId) {
        setActiveId(res.session_id);
        await loadSessions();
      }
      setMessages((m) => [...m, { role: 'assistant', content: res.reply, tool_calls: res.tool_calls }]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memproses');
      setMessages((m) => [...m, { role: 'assistant', content: 'Terjadi kesalahan: ' + (e instanceof Error ? e.message : e) }]);
    } finally {
      setBusy(false);
    }
  };

  const newSession = () => {
    setActiveId('');
    setMessages([]);
    setError(null);
  };

  const deleteSession = async (id: string) => {
    if (!window.confirm('Hapus percakapan ini?')) return;
    try {
      const { error } = await supabase.functions.invoke('system_console', { body: { action: 'delete', session_id: id } });
      if (error) throw error;
      if (activeId === id) newSession();
      await loadSessions();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal menghapus sesi');
    }
  };

  const renderToolCalls = (toolCalls: unknown) => {
    if (!toolCalls || !Array.isArray(toolCalls) || !toolCalls.length) return null;
    const logs = toolCalls as ToolLog[];
    return (
      <div className="mt-2 space-y-1">
        {logs.map((t, i) => (
          <div key={i} className="flex items-start gap-1.5 text-[10px] font-mono bg-bg border border-border rounded-lg px-2 py-1 text-muted">
            <TerminalSquare className="w-3 h-3 mt-0.5 shrink-0 text-primary" />
            <span className="truncate">
              <span className="font-bold text-ink">{t.name}</span>
              {t.mode ? <span className="mx-1 text-primary">{t.mode}</span> : null}
              <span className="text-muted">{t.sql?.slice(0, 70) || ''}</span>
              <span className={t.ok ? 'text-success' : 'text-danger'}>{t.ok ? ' ✓' : ' ✗'}</span>
            </span>
          </div>
        ))}
      </div>
    );
  };

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-ink mb-1 flex items-center gap-2">
            <Bot className="w-6 h-6 text-primary" /> Console AI
          </h1>
          <p className="text-xs sm:text-sm text-muted">
            Asisten teknis superadmin — periksa &amp; perbaiki sistem lewat database (SQL read/write), dengan kunci AI dari Control Plane
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={loadSessions} className="flex items-center gap-2 border border-border bg-surface px-4 py-2.5 rounded-xl text-xs font-semibold text-muted hover:bg-bg transition">
            <RefreshCw className="w-4 h-4" /> Muat Ulang
          </button>
          <button onClick={newSession} className="flex items-center gap-2 ocean-gradient text-white px-4 py-2.5 rounded-xl text-xs font-semibold shadow-sm active:scale-95 transition">
            <Plus className="w-4 h-4" /> Percakapan Baru
          </button>
        </div>
      </div>

      {error && (
        <div className="mb-4 flex items-center gap-2 bg-danger/10 border border-danger/30 text-danger rounded-xl px-4 py-3 text-xs font-semibold">
          {error}
        </div>
      )}

      <div className="grid lg:grid-cols-[260px_1fr] gap-4">
        {/* Riwayat sesi */}
        <div className="bg-surface rounded-2xl card-shadow border border-border/80 p-3 h-fit lg:sticky lg:top-4">
          <h2 className="text-xs font-bold text-ink mb-2 flex items-center gap-2 px-1">
            <History className="w-4 h-4 text-primary" /> Riwayat
          </h2>
          {loading ? (
            <p className="text-xs text-muted p-2">Memuat...</p>
          ) : !sessions.length ? (
            <p className="text-xs text-muted p-2">Belum ada percakapan.</p>
          ) : (
            <ul className="space-y-1 max-h-[60vh] overflow-y-auto">
              {sessions.map((s) => (
                <li key={s.id}>
                  <button
                    onClick={() => setActiveId(s.id)}
                    className={`w-full text-left flex items-center gap-1.5 px-2.5 py-2 rounded-xl text-xs font-semibold transition ${
                      activeId === s.id ? 'bg-primary text-white' : 'text-muted hover:bg-bg hover:text-ink'
                    }`}
                  >
                    <span className="flex-1 truncate">{s.title ?? 'Tanpa judul'}</span>
                    <span
                      onClick={(e) => { e.stopPropagation(); deleteSession(s.id); }}
                      className="p-1 rounded-md hover:bg-black/10 transition"
                      title="Hapus"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Chat */}
        <div className="bg-surface rounded-2xl card-shadow border border-border/80 flex flex-col min-h-[60vh] max-h-[78vh]">
          <div ref={scrollRef} className="flex-1 overflow-y-auto p-4 space-y-3">
            {!messages.length && (
              <div className="h-full flex flex-col items-center justify-center text-center text-muted py-10 px-6">
                <div className="w-14 h-14 rounded-2xl bg-primary/10 border border-primary/30 flex items-center justify-center mb-4">
                  <Sparkles className="w-6 h-6 text-primary" />
                </div>
                <p className="text-sm font-semibold text-ink mb-1">Console AI siap membantu</p>
                <p className="text-xs max-w-sm leading-relaxed">
                  Contoh: &ldquo;Berapa total outlet dan transaksi hari ini?&rdquo;,
                  &ldquo;Tampilkan 5 outlet terbaru&rdquo;, atau
                  &ldquo;Periksa produk dengan stok 0&rdquo;.
                  Untuk mengubah data, konsol akan memakai mode tulis (tercatat di audit).
                </p>
              </div>
            )}

            {messages.map((m, i) => (
              <div key={i} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                <div className={`max-w-[85%] ${m.role === 'user' ? '' : 'w-full sm:max-w-[90%]'}`}>
                  {m.role === 'user' ? (
                    <div className="bg-primary text-white px-4 py-2.5 rounded-2xl rounded-br-sm text-sm whitespace-pre-wrap">
                      {m.content}
                    </div>
                  ) : (
                    <div className="bg-bg border border-border px-4 py-2.5 rounded-2xl rounded-bl-sm">
                      <div className="text-[10px] font-bold text-primary uppercase tracking-wider flex items-center gap-1 mb-1">
                        <Bot className="w-3 h-3" /> Console AI
                      </div>
                      <div className="text-sm text-ink whitespace-pre-wrap leading-relaxed">{m.content}</div>
                      {renderToolCalls(m.tool_calls)}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>

          <div className="border-t border-border p-3">
            <div className="flex items-end gap-2">
              <textarea
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
                }}
                rows={2}
                placeholder="Tanyakan atau perintahkan perbaikan sistem..."
                className="flex-1 resize-none border border-border rounded-xl px-4 py-2.5 text-sm bg-surface text-ink focus:outline-none focus:ring-2 focus:ring-primary/40"
              />
              <button
                onClick={send}
                disabled={busy || !input.trim()}
                className="ocean-gradient text-white p-3 rounded-xl font-semibold shadow-sm active:scale-95 transition disabled:opacity-50"
                title="Kirim"
              >
                {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
              </button>
            </div>
            <p className="text-[10px] text-muted mt-2">
              Kunci AI dibaca dari <span className="font-semibold">Control Plane → Dokter Bisnis AI → Konfigurasi API AI</span>. Operasi tulis (mode <span className="font-mono">write</span>) dicatat ke audit.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}