import { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '../config/supabase';
import { rp } from '../lib/adminApi';
import {
  LifeBuoy,
  RefreshCw,
  Search,
  Send,
  Trash2,
  X,
  CheckCircle2,
  Clock3,
  MessageSquare,
  FileText,
} from 'lucide-react';

type TicketRow = {
  id: string;
  outlet_id: string;
  subject: string;
  description: string | null;
  status: 'open' | 'proses' | 'close';
  created_at: string;
  updated_at: string;
  closed_at: string | null;
  outlets?: { name: string | null } | null;
  support_ticket_replies?: { id: string }[] | null;
};

type ReplyRow = {
  id: string;
  ticket_id: string;
  author_uid: string | null;
  author_role: 'owner' | 'staf' | 'superadmin';
  body: string;
  created_at: string;
};

type AttachmentRow = {
  id: string;
  ticket_id: string;
  reply_id: string | null;
  file_name: string;
  mime_type: string | null;
  size_bytes: number | null;
  storage_path: string;
  created_at: string;
};

const formatBytes = (bytes: number | null | undefined) => {
  if (!bytes || bytes <= 0) return '';
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  if (bytes >= 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${bytes} B`;
};

function AttachmentList({
  items,
  urls,
  platform,
}: {
  items: AttachmentRow[];
  urls: Record<string, string>;
  platform: boolean;
}) {
  if (items.length === 0) return null;
  return (
    <div className="mt-2 flex flex-wrap gap-2">
      {items.map((a) => {
        const url = urls[a.id];
        const isImage = (a.mime_type ?? '').startsWith('image/');
        if (isImage && url) {
          return (
            <a
              key={a.id}
              href={url}
              target="_blank"
              rel="noreferrer"
              className="block w-28 h-20 rounded-lg overflow-hidden border border-border/60 bg-bg"
              title={a.file_name}
            >
              <img
                src={url}
                alt={a.file_name}
                className="w-full h-full object-cover"
                loading="lazy"
              />
            </a>
          );
        }
        return (
          <a
            key={a.id}
            href={url ?? undefined}
            target="_blank"
            rel="noreferrer"
            className={`flex items-center gap-1.5 max-w-[190px] px-2 py-1.5 rounded-lg border text-[10px] ${
              platform
                ? 'border-white/30 bg-white/10 text-white'
                : 'border-border bg-bg text-ink'
            }`}
            title={a.file_name}
          >
            <FileText className="w-3.5 h-3.5 shrink-0" />
            <span className="truncate">{a.file_name}</span>
            <span className={platform ? 'text-white/60' : 'text-muted'}>
              {formatBytes(a.size_bytes)}
            </span>
          </a>
        );
      })}
    </div>
  );
}

const STATUS_META: Record<string, { label: string; cls: string; icon: typeof Clock3 }> = {
  open: { label: 'Menunggu', cls: 'bg-primary/10 text-primary border-primary/30', icon: Clock3 },
  proses: { label: 'Diproses', cls: 'bg-warning/10 text-warning border-warning/30', icon: MessageSquare },
  close: { label: 'Selesai', cls: 'bg-success/10 text-success border-success/30', icon: CheckCircle2 },
};

const fmtDateTime = (iso: string | null | undefined) => {
  if (!iso) return '-';
  const d = new Date(iso);
  return d.toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

export function SupportTicketsPage() {
  const [tickets, setTickets] = useState<TicketRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<'all' | 'open' | 'proses' | 'close'>('all');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<TicketRow | null>(null);
  const [replies, setReplies] = useState<ReplyRow[]>([]);
  const [attachments, setAttachments] = useState<AttachmentRow[]>([]);
  const [signedUrls, setSignedUrls] = useState<Record<string, string>>({});
  const [detailLoading, setDetailLoading] = useState(false);
  const [body, setBody] = useState('');
  const [sending, setSending] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data, error: err } = await supabase
        .from('support_tickets')
        .select('*, outlets(name), support_ticket_replies(id)')
        .order('updated_at', { ascending: false })
        .limit(200);
      if (err) throw err;
      setTickets((data ?? []) as TicketRow[]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat tiket');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    const ch = supabase
      .channel('admin-support-tickets')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'support_tickets' },
        () => load(),
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'support_ticket_replies' },
        () => load(),
      )
      .subscribe();
    // Fallback polling: tabel support mungkin belum masuk publikasi realtime.
    const timer = window.setInterval(load, 20000);
    return () => {
      window.clearInterval(timer);
      supabase.removeChannel(ch);
    };
  }, [load]);

  const loadDetail = useCallback(async (ticket: TicketRow) => {
    setSelected(ticket);
    setReplies([]);
    setAttachments([]);
    setSignedUrls({});
    setDetailLoading(true);
    try {
      const { data, error: err } = await supabase
        .from('support_ticket_replies')
        .select('*')
        .eq('ticket_id', ticket.id)
        .order('created_at', { ascending: true });
      if (err) throw err;
      setReplies((data ?? []) as ReplyRow[]);

      const { data: attData } = await supabase
        .from('support_ticket_attachments')
        .select('*')
        .eq('ticket_id', ticket.id)
        .order('created_at', { ascending: true });
      const atts = (attData ?? []) as AttachmentRow[];
      setAttachments(atts);
      const urlMap: Record<string, string> = {};
      for (const a of atts) {
        const { data: signed } = await supabase.storage
          .from('support-attachments')
          .createSignedUrl(a.storage_path, 3600);
        if (signed?.signedUrl) urlMap[a.id] = signed.signedUrl;
      }
      setSignedUrls(urlMap);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat balasan');
    } finally {
      setDetailLoading(false);
    }
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return tickets.filter((t) => {
      if (status !== 'all' && t.status !== status) return false;
      if (!q) return true;
      return (
        t.subject.toLowerCase().includes(q) ||
        (t.outlets?.name ?? '').toLowerCase().includes(q)
      );
    });
  }, [tickets, status, search]);

  const counts = useMemo(
    () => ({
      all: tickets.length,
      open: tickets.filter((t) => t.status === 'open').length,
      proses: tickets.filter((t) => t.status === 'proses').length,
      close: tickets.filter((t) => t.status === 'close').length,
    }),
    [tickets],
  );

  const sendReply = async () => {
    if (!selected || !body.trim() || sending) return;
    setSending(true);
    setError(null);
    try {
      const { error: err } = await supabase.from('support_ticket_replies').insert({
        ticket_id: selected.id,
        author_uid: (await supabase.auth.getUser()).data.user?.id ?? null,
        author_role: 'superadmin',
        body: body.trim(),
      });
      if (err) throw err;
      if (selected.status === 'open') {
        await supabase.from('support_tickets').update({ status: 'proses' }).eq('id', selected.id);
      }
      try {
        await rp('log_admin_action', {
          p_action: 'support.reply',
          p_target: selected.id,
          p_meta: { subject: selected.subject },
        });
      } catch {
        /* audit opsional */
      }
      setBody('');
      await loadDetail(selected);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal mengirim balasan');
    } finally {
      setSending(false);
    }
  };

  const setTicketStatus = async (ticket: TicketRow, next: 'open' | 'proses' | 'close') => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      const { error: err } = await supabase
        .from('support_tickets')
        .update({ status: next })
        .eq('id', ticket.id);
      if (err) throw err;
      try {
        await rp('log_admin_action', {
          p_action: `support.status.${next}`,
          p_target: ticket.id,
          p_meta: { subject: ticket.subject },
        });
      } catch {
        /* audit opsional */
      }
      if (selected?.id === ticket.id) {
        const updated = { ...selected, status: next };
        setSelected(updated);
        if (next === 'close') {
          const { data } = await supabase
            .from('support_tickets')
            .select('*, outlets(name), support_ticket_replies(id)')
            .eq('id', ticket.id)
            .maybeSingle();
          if (data) setSelected(data as TicketRow);
        }
      }
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal mengubah status');
    } finally {
      setBusy(false);
    }
  };

  const deleteTicket = async (ticket: TicketRow) => {
    if (!window.confirm(`Hapus tiket "${ticket.subject}"? Tindakan ini permanen.`)) return;
    setError(null);
    try {
      const { error: err } = await supabase.from('support_tickets').delete().eq('id', ticket.id);
      if (err) throw err;
      try {
        await rp('log_admin_action', {
          p_action: 'support.delete',
          p_target: ticket.id,
          p_meta: { subject: ticket.subject },
        });
      } catch {
        /* audit opsional */
      }
      if (selected?.id === ticket.id) setSelected(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal menghapus tiket');
    }
  };

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-5">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-ink mb-1 flex items-center gap-2">
            <LifeBuoy className="w-6 h-6 text-primary" /> Tiket Support
          </h1>
          <p className="text-xs sm:text-sm text-muted">
            Keluhan & pertanyaan owner/staf. Balas, ubah status (open/proses/close), atau hapus tiket.
          </p>
        </div>
        <button
          onClick={load}
          className="flex items-center gap-2 border border-border bg-surface px-4 py-2.5 rounded-xl text-xs font-semibold text-muted hover:bg-bg transition"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Muat Ulang
        </button>
      </div>

      {error && (
        <div className="mb-4 rounded-xl border border-danger/30 bg-danger/10 px-4 py-3 text-xs text-danger">
          {error}
        </div>
      )}

      <div className="flex flex-col sm:flex-row gap-3 mb-4">
        <div className="flex flex-wrap gap-2">
          {(['all', 'open', 'proses', 'close'] as const).map((key) => (
            <button
              key={key}
              onClick={() => setStatus(key)}
              className={`px-3 py-2 rounded-xl text-xs font-bold border transition ${
                status === key
                  ? 'bg-primary text-white border-primary shadow-sm'
                  : 'bg-surface text-muted border-border hover:bg-bg'
              }`}
            >
              {key === 'all' ? 'Semua' : STATUS_META[key].label} ({counts[key]})
            </button>
          ))}
        </div>
        <div className="relative sm:ml-auto">
          <Search className="w-4 h-4 text-muted absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari judul / nama outlet..."
            className="w-full sm:w-72 pl-9 pr-3 py-2.5 rounded-xl border border-border bg-surface text-xs text-ink outline-none focus:border-primary"
          />
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-4">
        <div className="lg:col-span-3 bg-surface border border-border rounded-2xl overflow-hidden">
          {loading && tickets.length === 0 ? (
            <div className="p-10 text-center text-xs text-muted">Memuat tiket...</div>
          ) : filtered.length === 0 ? (
            <div className="p-10 text-center text-xs text-muted">
              Belum ada tiket pada filter ini.
            </div>
          ) : (
            <ul className="divide-y divide-border">
              {filtered.map((t) => {
                const meta = STATUS_META[t.status] ?? STATUS_META.open;
                const Icon = meta.icon;
                const replyCount = t.support_ticket_replies?.length ?? 0;
                const active = selected?.id === t.id;
                return (
                  <li key={t.id}>
                    <button
                      onClick={() => loadDetail(t)}
                      className={`w-full text-left px-4 py-3.5 transition ${
                        active ? 'bg-primary/5' : 'hover:bg-bg'
                      }`}
                    >
                      <div className="flex items-center gap-2 mb-1.5">
                        <span
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-lg border text-[10px] font-bold ${meta.cls}`}
                        >
                          <Icon className="w-3 h-3" /> {meta.label}
                        </span>
                        <span className="text-[10px] text-muted truncate">
                          {t.outlets?.name ?? 'Outlet'}
                        </span>
                        <span className="ml-auto text-[10px] text-muted shrink-0">
                          {fmtDateTime(t.updated_at ?? t.created_at)}
                        </span>
                      </div>
                      <p className="text-sm font-bold text-ink line-clamp-1">{t.subject}</p>
                      {t.description && (
                        <p className="text-[11px] text-muted line-clamp-1 mt-0.5">
                          {t.description}
                        </p>
                      )}
                      <div className="flex items-center gap-1 mt-1.5 text-[10px] text-muted">
                        <MessageSquare className="w-3 h-3" /> {replyCount} balasan
                      </div>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <div className="lg:col-span-2">
          {!selected ? (
            <div className="bg-surface border border-border rounded-2xl p-8 text-center h-full flex flex-col items-center justify-center">
              <LifeBuoy className="w-10 h-10 text-border mb-3" />
              <p className="text-xs text-muted">Pilih tiket untuk melihat percakapan.</p>
            </div>
          ) : (
            <div className="bg-surface border border-border rounded-2xl flex flex-col h-[70vh] lg:h-[640px]">
              <div className="p-4 border-b border-border">
                <div className="flex items-start gap-2">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-bold text-ink">{selected.subject}</p>
                    <p className="text-[10px] text-muted">
                      {selected.outlets?.name ?? 'Outlet'} &bull; {fmtDateTime(selected.created_at)}
                    </p>
                  </div>
                  <button
                    onClick={() => setSelected(null)}
                    className="text-muted hover:text-ink p-1"
                    aria-label="Tutup detail"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
                {selected.description && (
                  <p className="text-[11px] text-muted mt-2 leading-relaxed">{selected.description}</p>
                )}
                <AttachmentList
                  items={attachments.filter((a) => !a.reply_id)}
                  urls={signedUrls}
                  platform={false}
                />
                <div className="flex flex-wrap gap-2 mt-3">
                  {(['open', 'proses', 'close'] as const).map((s) => (
                    <button
                      key={s}
                      disabled={busy || selected.status === s}
                      onClick={() => setTicketStatus(selected, s)}
                      className={`px-2.5 py-1.5 rounded-lg text-[10px] font-bold border transition disabled:opacity-40 ${
                        selected.status === s
                          ? 'bg-primary text-white border-primary'
                          : 'bg-surface text-muted border-border hover:bg-bg'
                      }`}
                    >
                      {STATUS_META[s].label}
                    </button>
                  ))}
                  <button
                    onClick={() => deleteTicket(selected)}
                    className="ml-auto flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-bold border border-danger/30 text-danger hover:bg-danger/10"
                  >
                    <Trash2 className="w-3 h-3" /> Hapus
                  </button>
                </div>
              </div>

              <div className="flex-1 overflow-y-auto p-3 space-y-2 bg-bg/40">
                {detailLoading ? (
                  <p className="text-center text-[11px] text-muted py-6">Memuat balasan...</p>
                ) : replies.length === 0 ? (
                  <p className="text-center text-[11px] text-muted py-6">
                    Belum ada balasan. Kirim balasan pertama di bawah.
                  </p>
                ) : (
                  replies.map((r) => {
                    const platform = r.author_role === 'superadmin';
                    return (
                      <div
                        key={r.id}
                        className={`max-w-[85%] rounded-xl px-3 py-2 border text-xs leading-relaxed ${
                          platform
                            ? 'ml-auto bg-primary text-white border-primary'
                            : 'bg-surface text-ink border-border'
                        }`}
                      >
                        <p
                          className={`text-[9px] font-bold mb-0.5 ${
                            platform ? 'text-white/80' : 'text-primary'
                          }`}
                        >
                          {platform
                            ? 'Tim KasirGo'
                            : r.author_role === 'owner'
                              ? 'Owner'
                              : 'Staf'}
                        </p>
                        <p className="whitespace-pre-wrap">{r.body}</p>
                        <AttachmentList
                          items={attachments.filter((a) => a.reply_id === r.id)}
                          urls={signedUrls}
                          platform={platform}
                        />
                        <p
                          className={`text-[9px] mt-1 ${
                            platform ? 'text-white/70' : 'text-muted'
                          }`}
                        >
                          {fmtDateTime(r.created_at)}
                        </p>
                      </div>
                    );
                  })
                )}
              </div>

              <div className="p-3 border-t border-border">
                <textarea
                  value={body}
                  onChange={(e) => setBody(e.target.value)}
                  rows={2}
                  placeholder={
                    selected.status === 'close'
                      ? 'Tiket sudah selesai. Kirim balasan untuk membuka kembali.'
                      : 'Tulis balasan untuk owner...'
                  }
                  className="w-full px-3 py-2 rounded-xl border border-border bg-bg text-xs text-ink outline-none focus:border-primary resize-none"
                />
                <button
                  onClick={sendReply}
                  disabled={sending || !body.trim()}
                  className="mt-2 w-full flex items-center justify-center gap-2 bg-primary text-white py-2.5 rounded-xl text-xs font-bold disabled:opacity-50"
                >
                  <Send className="w-3.5 h-3.5" /> {sending ? 'Mengirim...' : 'Kirim Balasan'}
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}