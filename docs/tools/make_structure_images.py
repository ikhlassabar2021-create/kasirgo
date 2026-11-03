#!/usr/bin/env python3
"""Render struktur kode UI KasirGo menjadi gambar PNG+SVG via Graphviz.

Menghasilkan 6 diagram di docs/diagrams/:
  struktur-lib, struktur-screens (overview), struktur-owner,
  struktur-staf, struktur-pelanggan, struktur-widgets.
"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, os.pardir, 'diagrams')
os.makedirs(OUT_DIR, exist_ok=True)

FOLDER_FILL = '#DBEAFE'
FILE_FILL = 'white'
PRIMARY = '#0284C7'
INK = '#0F172A'


def _esc(s):
    return s.replace('"', '\\"')


def _render(dot, name):
    dot_path = os.path.join(OUT_DIR, name + '.dot')
    png_path = os.path.join(OUT_DIR, name + '.png')
    svg_path = os.path.join(OUT_DIR, name + '.svg')
    with open(dot_path, 'w', encoding='utf-8') as f:
        f.write(dot)
    for fmt, out in (('png', png_path), ('svg', svg_path)):
        subprocess.run(['dot', '-T' + fmt, '-Gdpi=140', dot_path, '-o', out], check=True)
    print('OK -> %s' % name)


def tree(root_label, items, name):
    lines = [
        'digraph G {',
        '  rankdir=LR;',
        '  graph [splines=ortho, nodesep=0.4, ranksep=0.6, bgcolor="white"];',
        '  node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=11, margin="0.12,0.07"];',
        '  edge [color="#94A3B8", arrowsize=0.65];',
    ]
    counter = [0]

    def add(label, kind):
        counter[0] += 1
        nid = 'n%d' % counter[0]
        if kind == 'folder':
            lines.append('  %s [label="%s", fillcolor="%s", color="%s", fontcolor="%s"];'
                         % (nid, _esc(label), FOLDER_FILL, PRIMARY, INK))
        elif kind == 'root':
            lines.append('  %s [label="%s", fillcolor="%s", color="%s", fontcolor="white", penwidth=2];'
                         % (nid, _esc(label), PRIMARY, PRIMARY))
        else:
            lines.append('  %s [label="%s", fillcolor="white", color="#CBD5E1", fontcolor="%s"];'
                         % (nid, _esc(label), INK))
        return nid

    root_id = add(root_label, 'root')
    stack = [(root_id, items)]
    while stack:
        parent, children = stack.pop()
        for label, kind, sub in children:
            cid = add(label, kind)
            lines.append('  %s -> %s;' % (parent, cid))
            if sub:
                stack.append((cid, sub))

    lines.append('}')
    _render('\n'.join(lines), name)


def main():
    tree('kasirgo/lib/', [
        ('main.dart', 'file', []),
        ('app.dart', 'file', []),
        ('config/', 'folder', [
            ('app_theme.dart — design system', 'file', []),
            ('constants.dart — versi', 'file', []),
            ('supabase_config.dart — URL', 'file', []),
        ]),
        ('core/ — util inti', 'folder', []),
        ('models/ — data classes', 'folder', []),
        ('providers/ — Riverpod', 'folder', []),
        ('services/ — Supabase/AI', 'folder', []),
        ('utils/ — helper', 'folder', []),
        ('screens/ — halaman UI', 'folder', []),
        ('widgets/ — komponen UI', 'folder', []),
    ], 'struktur-lib')

    tree('screens/', [
        ('auth/', 'folder', []),
        ('buyer/', 'folder', []),
        ('owner/', 'folder', []),
        ('admin/', 'folder', []),
        ('cashier/', 'folder', []),
        ('kitchen/', 'folder', []),
        ('customer/', 'folder', []),
        ('modules/', 'folder', []),
    ], 'struktur-screens')

    tree('screens/owner/', [
        ('owner_home_screen.dart — dashboard', 'file', []),
        ('pos_screen.dart — kasir/POS', 'file', []),
        ('product_list_screen.dart', 'file', []),
        ('product_form_screen.dart', 'file', []),
        ('customer_list_screen.dart', 'file', []),
        ('employee_screen.dart', 'file', []),
        ('shift_screen.dart', 'file', []),
        ('report_screen.dart', 'file', []),
        ('report_schedule_screen.dart', 'file', []),
        ('staff_performance_screen.dart', 'file', []),
        ('qr_table_screen.dart', 'file', []),
        ('online_catalog_screen.dart', 'file', []),
        ('whatsapp_broadcast_screen.dart', 'file', []),
        ('settings_screen.dart', 'file', []),
        ('guide_screen.dart', 'file', []),
        ('help_center_screen.dart', 'file', []),
        ('support_tickets_screen.dart', 'file', []),
        ('debt_screen.dart', 'file', []),
        ('multi_outlet_screen.dart', 'file', []),
        ('affiliate_owner_screen.dart', 'file', []),
        ('health_score_screen.dart', 'file', []),
        ('business_doctor_screen.dart — AI', 'file', []),
        ('doctor_intake_screen.dart', 'file', []),
        ('doctor_cases_screen.dart', 'file', []),
        ('doctor_result_screen.dart', 'file', []),
        ('doctor_promotion_log_screen.dart', 'file', []),
        ('doctor_rapor_roi_screen.dart', 'file', []),
        ('doctor_scaling_screen.dart', 'file', []),
        ('doctor_vitals_screen.dart', 'file', []),
        ('dynamic_pricing_screen.dart', 'file', []),
        ('bundle_manager_screen.dart', 'file', []),
        ('referral_screen.dart', 'file', []),
        ('promotion_screen.dart', 'file', []),
        ('design_studio_screen.dart', 'file', []),
        ('ads_studio_screen.dart', 'file', []),
        ('sidak_bos_screen.dart', 'file', []),
        ('sidak_stock_count_screen.dart', 'file', []),
        ('progress_tracker_screen.dart', 'file', []),
        ('app_update_screen.dart', 'file', []),
        ('lapak_live_screen.dart', 'file', []),
        ('hyperlocal_screen.dart', 'file', []),
        ('midtrans_connect_screen.dart', 'file', []),
        ('delegation_board_screen.dart', 'file', []),
    ], 'struktur-owner')

    tree('staf toko (auth, admin, cashier, kitchen)', [
        ('auth/', 'folder', [
            ('login_screen.dart', 'file', []),
            ('register_screen.dart', 'file', []),
            ('onboarding_kyc_screen.dart — form KYC', 'file', []),
            ('kyc_upload_screen.dart — foto KTP', 'file', []),
        ]),
        ('admin/', 'folder', [
            ('admin_home_screen.dart', 'file', []),
        ]),
        ('cashier/', 'folder', [
            ('cashier_home_screen.dart', 'file', []),
            ('cashier_pos_screen.dart', 'file', []),
            ('cashier_report_screen.dart', 'file', []),
            ('incoming_orders_screen.dart', 'file', []),
            ('online_orders_screen.dart', 'file', []),
        ]),
        ('kitchen/', 'folder', [
            ('kitchen_home_screen.dart — KDS', 'file', []),
        ]),
    ], 'struktur-staf')

    tree('pelanggan & modul (buyer, customer, modules)', [
        ('buyer/', 'folder', [
            ('mode_gate.dart', 'file', []),
            ('mode_select_screen.dart', 'file', []),
            ('buyer_shell.dart', 'file', []),
            ('buyer_home_tab.dart — radar toko', 'file', []),
            ('buyer_auth_screen.dart', 'file', []),
            ('buyer_onboarding_screen.dart', 'file', []),
            ('buyer_checkout_screen.dart', 'file', []),
            ('buyer_order_tracking_screen.dart', 'file', []),
            ('buyer_help_screen.dart', 'file', []),
        ]),
        ('customer/', 'folder', [
            ('customer_menu_screen.dart', 'file', []),
            ('customer_catalog_screen.dart', 'file', []),
            ('customer_order_screen.dart', 'file', []),
        ]),
        ('modules/', 'folder', [
            ('debt_screen.dart', 'file', []),
            ('kitchen_display_screen.dart — KDS', 'file', []),
            ('ppob_screen.dart — pulsa/token', 'file', []),
            ('restock_screen.dart — B2B', 'file', []),
            ('supporter_screen.dart — Pendukung', 'file', []),
        ]),
    ], 'struktur-pelanggan')

    tree('widgets/', [
        ('pos/', 'folder', [
            ('cart_panel.dart', 'file', []),
            ('checkout_dialog.dart', 'file', []),
            ('checkout_success_dialog.dart', 'file', []),
            ('product_grid.dart', 'file', []),
        ]),
        ('ads/', 'folder', [
            ('sponsor_ad_slot.dart — iklan pelanggan', 'file', []),
        ]),
        ('guide/', 'folder', [
            ('guide_mock.dart — panduan bergambar', 'file', []),
        ]),
        ('common/', 'folder', [
            ('app_button.dart / app_card.dart', 'file', []),
            ('app_text_field.dart / app_badge.dart', 'file', []),
            ('app_drawer.dart / app_close_button.dart', 'file', []),
            ('app_dropdown_field.dart', 'file', []),
            ('app_empty_state.dart', 'file', []),
            ('error_widget.dart / loading_widget.dart', 'file', []),
            ('logout_button.dart / search_bar.dart', 'file', []),
            ('glass_card.dart / bubble_glass.dart', 'file', []),
            ('centennial_background.dart', 'file', []),
            ('responsive.dart — mobile/tablet/desktop', 'file', []),
            ('stock_badge.dart — badge stok', 'file', []),
            ('kyc_gate.dart — gerbang KYC', 'file', []),
            ('web_install_gate.dart — web ke APK', 'file', []),
            ('supporter_gate.dart — gerbang premium', 'file', []),
            ('delegation_tasks_card.dart', 'file', []),
            ('dm_channel_connect_sheet.dart', 'file', []),
            ('dynamic_qris_sheet.dart — QRIS dinamis', 'file', []),
            ('doctor_badge_chip.dart', 'file', []),
            ('business_doctor/doctor_blocks.dart — blok AI', 'file', []),
        ]),
    ], 'struktur-widgets')


if __name__ == '__main__':
    main()