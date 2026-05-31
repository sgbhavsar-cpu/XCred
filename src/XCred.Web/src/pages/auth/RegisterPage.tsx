import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { zodResolver } from '@hookform/resolvers/zod';
import { ShieldCheck, Eye, EyeOff, AlertTriangle } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { deriveKey, generateSalt, generateKeyPair, encryptPrivateKey } from '@/lib/crypto';
import { passwordStrength } from '@/lib/crypto';

const schema = z.object({
  username: z.string().min(3, 'Minimum 3 characters').max(100),
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'Minimum 8 characters'),
  confirmPassword: z.string(),
  masterPassword: z.string().min(12, 'Master password must be at least 12 characters'),
  confirmMasterPassword: z.string(),
  acknowledgeNoRecovery: z.boolean().refine(v => v === true, 'You must acknowledge this'),
}).refine(d => d.password === d.confirmPassword, { message: "Passwords don't match", path: ['confirmPassword'] })
  .refine(d => d.masterPassword === d.confirmMasterPassword, { message: "Master passwords don't match", path: ['confirmMasterPassword'] });

type FormData = z.infer<typeof schema>;

export default function RegisterPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [loadingStep, setLoadingStep] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showMaster, setShowMaster] = useState(false);
  const [masterPwd, setMasterPwd] = useState('');

  const { register, handleSubmit, formState: { errors }, watch } = useForm<FormData>({ resolver: zodResolver(schema) });

  const pwdValue = watch('password', '');
  const strength = passwordStrength(masterPwd);

  const onSubmit = async (data: FormData) => {
    setLoading(true);
    try {
      setLoadingStep('Deriving encryption key…');
      const salt = generateSalt();
      const symmetricKey = await deriveKey(data.masterPassword, salt);

      setLoadingStep('Generating key pair…');
      const { publicKey, privateKey: privateKeyB64 } = await generateKeyPair();
      const { encryptedPrivateKey, iv: privateKeyIv } = await encryptPrivateKey(symmetricKey, privateKeyB64);

      setLoadingStep('Creating account…');

      await api.post('/auth/register', {
        username: data.username,
        email: data.email,
        password: data.password,
        publicKey,
        encryptedPrivateKey,
        privateKeyIv,
        keyDerivationSalt: salt,
      });

      toast.success('Account created! Awaiting admin approval before you can log in.');
      navigate('/login');
    } catch (err: any) {
      const msg = err.response?.data?.error?.message ?? 'Registration failed. Check that the API server is running.';
      toast.error(msg);
    } finally {
      setLoading(false);
      setLoadingStep('');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 flex items-center justify-center p-4">
      <div className="w-full max-w-lg">
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <div className="flex flex-col items-center mb-6">
            <div className="bg-indigo-600 rounded-2xl p-3 mb-3">
              <ShieldCheck className="w-8 h-8 text-white" />
            </div>
            <h1 className="text-2xl font-bold text-slate-900">Create Account</h1>
            <p className="text-slate-500 text-sm mt-1">Join XCred — your secure credential vault</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Username</label>
                <input {...register('username')} className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm" autoComplete="username" />
                {errors.username && <p className="text-red-500 text-xs mt-1">{errors.username.message}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Email</label>
                <input {...register('email')} type="email" className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm" autoComplete="email" />
                {errors.email && <p className="text-red-500 text-xs mt-1">{errors.email.message}</p>}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Login Password</label>
                <div className="relative">
                  <input {...register('password')} type={showPassword ? 'text' : 'password'} className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm pr-8" />
                  <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400">
                    {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                  </button>
                </div>
                {pwdValue && (
                  <div className="mt-1">
                    <div className="h-1 rounded bg-gray-200">
                      <div className={`h-1 rounded transition-all ${passwordStrength(pwdValue).color}`} style={{ width: `${(passwordStrength(pwdValue).score + 1) * 20}%` }} />
                    </div>
                  </div>
                )}
                {errors.password && <p className="text-red-500 text-xs mt-1">{errors.password.message}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Confirm Password</label>
                <input {...register('confirmPassword')} type="password" className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm" />
                {errors.confirmPassword && <p className="text-red-500 text-xs mt-1">{errors.confirmPassword.message}</p>}
              </div>
            </div>

            <div className="border-t border-slate-100 pt-4">
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">Master Password (Vault Encryption Key)</p>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Master Password</label>
                  <div className="relative">
                    <input {...register('masterPassword')} type={showMaster ? 'text' : 'password'}
                      onChange={e => setMasterPwd(e.target.value)}
                      className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm pr-8" autoComplete="off" />
                    <button type="button" onClick={() => setShowMaster(!showMaster)} className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400">
                      {showMaster ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                  {masterPwd && (
                    <div className="mt-1 flex items-center gap-2">
                      <div className="flex-1 h-1 rounded bg-gray-200">
                        <div className={`h-1 rounded transition-all ${strength.color}`} style={{ width: `${(strength.score + 1) * 20}%` }} />
                      </div>
                      <span className="text-xs text-slate-500">{strength.label}</span>
                    </div>
                  )}
                  {errors.masterPassword && <p className="text-red-500 text-xs mt-1">{errors.masterPassword.message}</p>}
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Confirm Master Password</label>
                  <input {...register('confirmMasterPassword')} type="password" className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm" autoComplete="off" />
                  {errors.confirmMasterPassword && <p className="text-red-500 text-xs mt-1">{errors.confirmMasterPassword.message}</p>}
                </div>
              </div>
            </div>

            <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
              <AlertTriangle className="w-4 h-4 text-amber-600 mt-0.5 shrink-0" />
              <p className="text-xs text-amber-700">
                Your master password is used to encrypt your vault locally. It is <strong>never sent to the server</strong>.
                If you lose it, <strong>your data cannot be recovered</strong>. Store it safely.
              </p>
            </div>

            <label className="flex items-start gap-2 cursor-pointer">
              <input {...register('acknowledgeNoRecovery')} type="checkbox" className="mt-0.5 rounded border-slate-300 text-indigo-600" />
              <span className="text-xs text-slate-600">I understand that if I forget my master password, my vault data cannot be recovered.</span>
            </label>
            {errors.acknowledgeNoRecovery && <p className="text-red-500 text-xs">{errors.acknowledgeNoRecovery.message}</p>}

            <button type="submit" disabled={loading}
              className="w-full bg-indigo-600 text-white py-2.5 rounded-lg font-medium hover:bg-indigo-700 disabled:opacity-60 disabled:cursor-not-allowed transition-colors">
              {loading ? (loadingStep || 'Creating account…') : 'Create Account'}
            </button>
          </form>

          <p className="text-center text-sm text-slate-500 mt-4">
            Already have an account?{' '}
            <Link to="/login" className="text-indigo-600 hover:underline font-medium">Sign in</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
