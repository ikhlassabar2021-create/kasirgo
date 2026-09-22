// supabase/functions/verify_kyc_flutter/index.ts
// KYC Verification Edge Function for Flutter app

import "https://deno.land/x/denoize@2.1.0/mod.ts";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

serve(async (req) => {
  try {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    };

    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }

    const body = await req.json();
    const { ktpPath, selfiePath, outletId, userId } = body;

    // Validate required fields
    if (!ktpPath || !selfiePath || !outletId || !userId) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: ktpPath, selfiePath, outletId, userId' }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Mock face recognition & KYC verification logic
    // In production, integrate with AI services like AWS Rekognition or Cloud Vision
    const mockFaceMatchScore = Math.floor(Math.random() * 30) + 70; // 70-100 range
    
    let verificationStatus: 'verified' | 'rejected' | 'manual_review' = 'manual_review';
    let notes = '';

    if (mockFaceMatchScore >= 85) {
      verificationStatus = 'verified';
      notes = 'Automatic approval: High face match confidence';
    } else if (mockFaceMatchScore < 60) {
      verificationStatus = 'rejected';
      notes = 'Low face match score below threshold';
    } else {
      verificationStatus = 'manual_review';
      notes = `Face match score ${mockFaceMatchScore}% - requires manual review`;
    }

    // Update outlet_kyc table
    const kycData = {
      ktp_path: ktpPath,
      selfie_path: selfiePath,
      face_match_score: mockFaceMatchScore,
      verification_status: verificationStatus,
      verified_at: new Date().toISOString(),
      verified_by: userId,
      notes: notes,
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabase
      .from('outlet_kyc')
      .update(kycData)
      .eq('outlet_id', outletId)
      .eq('owner_nik', body.nik)
      .select()
      .single();

    if (error) {
      console.error('Database error:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to update KYC record', details: error.message }),
        { status: 500, headers: corsHeaders }
      );
    }

    // If verified, update outlets table to mark kyc_verified
    if (verificationStatus === 'verified') {
      await supabase
        .from('outlets')
        .update({ 
          kyc_verified: true,
          is_active: true 
        })
        .eq('id', outletId);
    }

    return new Response(
      JSON.stringify({
        success: true,
        verification_status: verificationStatus,
        face_match_score: mockFaceMatchScore,
        message: notes,
        kyc_record: data,
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('Edge function error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
