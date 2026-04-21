import { createSlice, createAsyncThunk } from "@reduxjs/toolkit";
import type { AuthUser } from "src/auth/roles";

interface AuthState {
  user: AuthUser | null;
  status: "idle" | "loading" | "failed";
  error: string | null;
  checked: boolean;
}

const initialState: AuthState = {
  user: null,
  status: "idle",
  error: null,
  checked: false,
};

const DOGTAG_ROLE_MAP: Record<string, string> = {
  Administrators: "administrator",
  "Certificate Manager Agents": "agent",
  Auditors: "auditor",
  "Enterprise CA Administrators": "administrator",
  "Enterprise KRA Administrators": "administrator",
  "Enterprise OCSP Administrators": "administrator",
  "Enterprise TKS Administrators": "administrator",
  "Enterprise TPS Administrators": "administrator",
};

function mapRoles(rawRoles: string[]): string[] {
  const mapped = new Set<string>();
  for (const role of rawRoles) {
    const m = DOGTAG_ROLE_MAP[role];
    if (m) mapped.add(m);
  }
  return [...mapped];
}

function parseAccountResponse(data: {
  id: string;
  FullName: string;
  Email: string;
  Roles: string[];
}): AuthUser {
  return {
    username: data.id,
    fullName: data.FullName || data.id,
    email: data.Email || "",
    roles: mapRoles(data.Roles || []),
  };
}

export const loginUser = createAsyncThunk(
  "auth/login",
  async (
    { username, password }: { username: string; password: string },
    { rejectWithValue },
  ) => {
    const auth = btoa(`${username}:${password}`);
    const res = await fetch("/ca/rest/account/login", {
      method: "GET",
      headers: {
        Accept: "application/json",
        Authorization: `Basic ${auth}`,
      },
      credentials: "include",
    });
    if (!res.ok) return rejectWithValue("Invalid username or password");
    const data = await res.json();
    return parseAccountResponse(data);
  },
);

export const logoutUser = createAsyncThunk("auth/logout", async () => {
  await fetch("/ca/rest/account/logout", {
    method: "GET",
    credentials: "include",
  });
});

export const checkSession = createAsyncThunk(
  "auth/check",
  async (_, { rejectWithValue }) => {
    const res = await fetch("/ca/rest/account/login", {
      method: "GET",
      headers: { Accept: "application/json" },
      credentials: "include",
    });
    if (!res.ok) return rejectWithValue("Not authenticated");
    const data = await res.json();
    return parseAccountResponse(data);
  },
);

export const certLogin = createAsyncThunk(
  "auth/certLogin",
  async (_, { rejectWithValue }) => {
    // Tomcat handles client cert natively in the TLS handshake.
    // Calling /ca/rest/account/login lets Tomcat authenticate via cert.
    const res = await fetch("/ca/rest/account/login", {
      method: "GET",
      headers: { Accept: "application/json" },
      credentials: "include",
    });
    if (!res.ok) return rejectWithValue("Certificate authentication failed");
    const data = await res.json();
    return parseAccountResponse(data);
  },
);

export const checkCertAvailable = createAsyncThunk(
  "auth/checkCert",
  async () => {
    // In the Tomcat model, cert availability depends on whether the browser
    // has a client cert for this origin. Show cert login button on HTTPS.
    const isTls = window.location.protocol === "https:";
    return { hasCert: isTls, subjectDN: null, verified: false };
  },
);

const authSlice = createSlice({
  name: "auth",
  initialState,
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(loginUser.pending, (state) => {
        state.status = "loading";
        state.error = null;
      })
      .addCase(loginUser.fulfilled, (state, action) => {
        state.status = "idle";
        state.user = action.payload;
        state.error = null;
        state.checked = true;
      })
      .addCase(loginUser.rejected, (state, action) => {
        state.status = "failed";
        state.error = (action.payload as string) ?? "Login failed";
        state.checked = true;
      })
      .addCase(logoutUser.fulfilled, (state) => {
        state.user = null;
        state.status = "idle";
        state.error = null;
      })
      .addCase(checkSession.fulfilled, (state, action) => {
        state.user = action.payload;
        state.checked = true;
      })
      .addCase(checkSession.rejected, (state) => {
        state.user = null;
        state.checked = true;
      })
      .addCase(certLogin.pending, (state) => {
        state.status = "loading";
        state.error = null;
      })
      .addCase(certLogin.fulfilled, (state, action) => {
        state.status = "idle";
        state.user = action.payload;
        state.error = null;
        state.checked = true;
      })
      .addCase(certLogin.rejected, (state) => {
        state.status = "idle";
        state.checked = true;
      });
  },
});

export default authSlice.reducer;
