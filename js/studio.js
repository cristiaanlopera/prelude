const SUPABASE_URL="https://uhsnlqbvgbvhfcasbyxf.supabase.co";
const SUPABASE_KEY="sb_publishable__lvQajtpPNhX2VERTg6bDQ_g8E7rIfY";
const client=window.supabase
  ? window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY)
  : null;


const codesTabBtn=document.getElementById("codesTabBtn");
const customersTabBtn=document.getElementById("customersTabBtn");
const rankingTabBtn=document.getElementById("rankingTabBtn");
const codesView=document.getElementById("codesView");
const customersView=document.getElementById("customersView");
const rankingView=document.getElementById("rankingView");
const refreshRankingBtn=document.getElementById("refreshRankingBtn");
const rankingAdminList=document.getElementById("rankingAdminList");
const rankingParticipants=document.getElementById("rankingParticipants");
const rankingLeader=document.getElementById("rankingLeader");
const rankingLargestLibrary=document.getElementById("rankingLargestLibrary");
const customerSearch=document.getElementById("customerSearch");
const customersList=document.getElementById("customersList");
const customerDetail=document.getElementById("customerDetail");
const closeCustomerDetail=document.getElementById("closeCustomerDetail");
const detailTitle=document.getElementById("detailTitle");
const editCustomerName=document.getElementById("editCustomerName");
const editCustomerPhone=document.getElementById("editCustomerPhone");
const editCustomerBookmarks=document.getElementById("editCustomerBookmarks");
const editCustomerTotal=document.getElementById("editCustomerTotal");
const customerSummary=document.getElementById("customerSummary");
const customerLibrary=document.getElementById("customerLibrary");
const customerCodes=document.getElementById("customerCodes");
const customerRewards=document.getElementById("customerRewards");
const customerEditStatus=document.getElementById("customerEditStatus");
const saveCustomerBtn=document.getElementById("saveCustomerBtn");
const resetCustomerBtn=document.getElementById("resetCustomerBtn");
const deleteCustomerBtn=document.getElementById("deleteCustomerBtn");
const confirmOverlay=document.getElementById("confirmOverlay");
const confirmTitle=document.getElementById("confirmTitle");
const confirmText=document.getElementById("confirmText");
const confirmInput=document.getElementById("confirmInput");
const cancelConfirmBtn=document.getElementById("cancelConfirmBtn");
const confirmActionBtn=document.getElementById("confirmActionBtn");

let customersCache=[];
let activeCustomerId=null;
let pendingDangerAction=null;

const loginCard=document.getElementById("loginCard");
const dashboard=document.getElementById("dashboard");
const loginStatus=document.getElementById("loginStatus");
const generateStatus=document.getElementById("generateStatus");
let lastCode="";
let lastMessage="";

function status(el,message,error=false){
  el.textContent=message;
  el.className="status"+(error?" error":"");
}

async function showDashboard(){
  loginCard.style.display="none";
  dashboard.classList.add("open");
  await loadHistory();
}

async function login(){
  const email=document.getElementById("email").value.trim();
  const password=document.getElementById("password").value;

  if(!client){
    status(loginStatus,"No se ha podido cargar la conexión con Supabase. Recarga la página.",true);
    return;
  }

  if(!email||!password){
    status(loginStatus,"Introduce tu correo y contraseña.",true);
    return;
  }

  status(loginStatus,"Accediendo...");
  document.getElementById("loginBtn").disabled=true;

  try{
    const { error }=await client.auth.signInWithPassword({email,password});

    if(error){
      status(loginStatus,"No se ha podido iniciar sesión: "+error.message,true);
      return;
    }

    status(loginStatus,"");
    await showDashboard();
  }catch(error){
    console.error(error);
    status(loginStatus,"Se ha producido un error de conexión. Inténtalo de nuevo.",true);
  }finally{
    document.getElementById("loginBtn").disabled=false;
  }
}

async function logout(){
  await client.auth.signOut();
  dashboard.classList.remove("open");
  loginCard.style.display="";
}


function switchStudioView(view){
  const showCodes=view==="codes";
  const showCustomers=view==="customers";
  const showRanking=view==="ranking";

  codesView.classList.toggle("active",showCodes);
  customersView.classList.toggle("active",showCustomers);
  rankingView.classList.toggle("active",showRanking);

  codesTabBtn.classList.toggle("active",showCodes);
  customersTabBtn.classList.toggle("active",showCustomers);
  rankingTabBtn.classList.toggle("active",showRanking);

  if(showCustomers)loadCustomers();
  if(showRanking)loadAdminRanking();
}


async function loadAdminRanking(){
  rankingAdminList.innerHTML='<p style="color:var(--muted)">Cargando ranking...</p>';
  refreshRankingBtn.disabled=true;
  refreshRankingBtn.textContent="Actualizando...";

  try{
    const {data,error}=await client.rpc("get_prelude_library_ranking",{
      input_phone:null,
      input_access_token:null
    });

    if(error)throw error;

    const ranking=Array.isArray(data?.top)?data.top:[];

    rankingParticipants.textContent=ranking.length;
    rankingLeader.textContent=ranking[0]?.alias||"—";
    rankingLargestLibrary.textContent=ranking.length
      ? `${ranking[0].library_count} obras`
      : "0 obras";

    if(!ranking.length){
      rankingAdminList.innerHTML='<p style="color:var(--muted)">Todavía no hay clientes participando en el ranking.</p>';
      return;
    }

    rankingAdminList.innerHTML=ranking.map(item=>`
      <div class="ranking-admin-row">
        <div class="ranking-admin-position">${item.position}º</div>
        <div>
          <div class="ranking-admin-name">${item.alias}</div>
          <div class="ranking-admin-meta">${item.level}</div>
        </div>
        <div class="ranking-admin-cell">
          <strong>${item.library_count}</strong><br>
          <span class="meta">Obras descubiertas</span>
        </div>
        <div class="ranking-admin-cell">
          <strong>${item.level}</strong><br>
          <span class="meta">Nivel actual</span>
        </div>
      </div>
    `).join("");
  }catch(error){
    console.error(error);
    rankingAdminList.innerHTML='<p class="error">No se pudo cargar el ranking: '+error.message+'</p>';
  }finally{
    refreshRankingBtn.disabled=false;
    refreshRankingBtn.textContent="Actualizar ranking";
  }
}

async function loadCustomers(){
  customersList.innerHTML='<p style="color:var(--muted)">Cargando clientes...</p>';
  const {data,error}=await client.rpc("admin_list_customers");

  if(error){
    customersList.innerHTML='<p class="error">No se pudieron cargar los clientes: '+error.message+'</p>';
    return;
  }

  customersCache=data||[];
  renderCustomers(customersCache);
}

function renderCustomers(customers){
  if(!customers.length){
    customersList.innerHTML='<p style="color:var(--muted)">Todavía no hay clientes.</p>';
    return;
  }

  customersList.innerHTML=customers.map(item=>`
    <div class="customer-row">
      <div><strong>${item.customer_name}</strong><div class="meta">${item.customer_phone}</div></div>
      <div><div>${item.library_count} obras</div><div class="meta">Colección Prelude</div></div>
      <div><div>${item.bookmarks}</div><div class="meta">Marcapáginas</div></div>
      <div><div>${Number(item.total_spent).toFixed(2).replace(".",",")} €</div><div class="meta">Total</div></div>
      <button type="button" data-customer-id="${item.id}">Ver cliente</button>
    </div>
  `).join("");

  customersList.querySelectorAll("[data-customer-id]").forEach(button=>{
    button.addEventListener("click",()=>openCustomer(button.dataset.customerId));
  });
}

async function openCustomer(customerId){
  const {data,error}=await client.rpc("admin_get_customer",{input_customer_id:customerId});
  if(error){
    alert("No se pudo abrir el cliente: "+error.message);
    return;
  }

  activeCustomerId=customerId;
  const customer=data.customer;
  detailTitle.textContent=customer.customer_name;
  editCustomerName.value=customer.customer_name;
  editCustomerPhone.value=customer.customer_phone;
  editCustomerBookmarks.value=customer.bookmarks;
  editCustomerTotal.value=Number(customer.total_spent).toFixed(2);

  customerSummary.innerHTML=`
    <div class="code-line"><strong>${data.library.length}</strong> obras descubiertas</div>
    <div class="code-line"><strong>${customer.bookmarks}</strong> Marcapáginas</div>
    <div class="code-line"><strong>${Number(customer.total_spent).toFixed(2).replace(".",",")} €</strong> acumulados</div>
    <div class="code-line">Miembro desde ${new Date(customer.created_at).toLocaleDateString("es-ES")}</div>
  `;

  customerLibrary.innerHTML=data.library.length
    ? data.library.map(item=>`<span class="library-pill">${item.perfume}</span>`).join("")
    : '<p style="color:var(--muted)">Sin descubrimientos.</p>';

  customerCodes.innerHTML=data.codes.length
    ? data.codes.map(item=>`
        <div class="code-line">
          <strong>${item.code}</strong> · Pedido #${item.order_number||"—"}<br>
          <span style="color:var(--muted)">
            ${Number(item.order_total||0).toFixed(2).replace(".",",")} € ·
            ${item.bookmarks_awarded||0} Marcapáginas ·
            ${item.is_redeemed?"Canjeado":"Pendiente"}
          </span>
        </div>
      `).join("")
    : '<p style="color:var(--muted)">Sin códigos asociados.</p>';

  customerRewards.innerHTML=data.rewards?.length
    ? data.rewards.map(reward=>`
        <div class="reward-admin-row">
          <strong>${reward.reward_label}</strong>
          <div class="reward-admin-meta">
            ${reward.threshold} Marcapáginas ·
            ${reward.status==="pending"?"Pendiente de entregar":"Canjeada"}
            ${reward.claimed_order_number?` · Pedido #${reward.claimed_order_number}`:""}
          </div>
          ${reward.status==="pending"
            ? `<button type="button" data-claim-reward="${reward.id}">Marcar como entregada</button>`
            : ""}
        </div>
      `).join("")
    : '<p style="color:var(--muted)">Sin recompensas desbloqueadas.</p>';

  customerRewards.querySelectorAll("[data-claim-reward]").forEach(button=>{
    button.addEventListener("click",async()=>{
      const orderNumber=prompt("Número del pedido en el que se ha entregado la recompensa (opcional):","")||"";
      const {error}=await client.rpc("admin_claim_customer_reward",{
        input_reward_id:button.dataset.claimReward,
        input_order_number:orderNumber
      });

      if(error){
        alert("No se pudo confirmar la recompensa: "+error.message);
        return;
      }

      await openCustomer(activeCustomerId);
      await loadCustomers();
    });
  });

  customerEditStatus.textContent="";
  customerDetail.classList.add("open");
}

async function saveCustomer(){
  if(!activeCustomerId)return;

  status(customerEditStatus,"Guardando...");
  const {error}=await client.rpc("admin_update_customer",{
    input_customer_id:activeCustomerId,
    input_customer_name:editCustomerName.value.trim(),
    input_customer_phone:editCustomerPhone.value.trim(),
    input_bookmarks:Number(editCustomerBookmarks.value),
    input_total_spent:Number(editCustomerTotal.value)
  });

  if(error){
    status(customerEditStatus,"No se pudo guardar: "+error.message,true);
    return;
  }

  status(customerEditStatus,"Cliente actualizado correctamente.");
  detailTitle.textContent=editCustomerName.value.trim();
  await loadCustomers();
}

function openDangerConfirm(type){
  pendingDangerAction=type;
  confirmOverlay.classList.add("open");
  confirmInput.value="";

  if(type==="delete"){
    confirmTitle.textContent="Eliminar definitivamente";
    confirmText.textContent="Se eliminarán el perfil, Mi Colección Prelude, los Marcapáginas y los códigos asociados. Escribe ELIMINAR para confirmar.";
    confirmInput.style.display="block";
    confirmActionBtn.textContent="Eliminar definitivamente";
  }else{
    confirmTitle.textContent="Reiniciar Colección Prelude";
    confirmText.textContent="Se borrarán los descubrimientos, los Marcapáginas y el total acumulado. El perfil y el PIN se conservarán.";
    confirmInput.style.display="none";
    confirmActionBtn.textContent="Reiniciar";
  }
}

function closeDangerConfirm(){
  pendingDangerAction=null;
  confirmOverlay.classList.remove("open");
}

async function executeDangerAction(){
  if(!activeCustomerId||!pendingDangerAction)return;

  if(pendingDangerAction==="delete"&&confirmInput.value.trim()!=="ELIMINAR"){
    alert("Escribe ELIMINAR exactamente para continuar.");
    return;
  }

  const functionName=pendingDangerAction==="delete"
    ?"admin_delete_customer"
    :"admin_reset_customer";

  const {error}=await client.rpc(functionName,{input_customer_id:activeCustomerId});

  if(error){
    alert("No se pudo completar la acción: "+error.message);
    return;
  }

  closeDangerConfirm();

  if(functionName==="admin_delete_customer"){
    customerDetail.classList.remove("open");
    activeCustomerId=null;
    await loadCustomers();
  }else{
    await openCustomer(activeCustomerId);
    await loadCustomers();
  }
}

function selectedPerfumes(){
  return [...document.querySelectorAll('#perfumes input:checked')].map(input=>input.value);
}

async function generateCode(){
  const customerName=document.getElementById("customerName").value.trim();
  const customerPhone=document.getElementById("customerPhone").value.trim();
  const orderNumber=document.getElementById("orderNumber").value.trim();
  const orderTotal=Number(document.getElementById("orderTotal").value);
  const perfumes=selectedPerfumes();

  if(!orderNumber||!customerName||!Number.isFinite(orderTotal)||orderTotal<0||perfumes.length===0){
    status(generateStatus,"Completa el número de pedido, el nombre, el total y al menos una fragancia.",true);
    return;
  }

  status(generateStatus,"Generando código...");
  const button=document.getElementById("generateBtn");
  button.disabled=true;

  const { data,error }=await client.rpc("admin_create_prelude_code",{
    input_customer_name:customerName,
    input_customer_phone:customerPhone,
    input_order_number:orderNumber,
    input_order_total:orderTotal,
    input_perfumes:perfumes
  });

  button.disabled=false;

  if(error){
    status(generateStatus,"No se ha podido generar: "+error.message,true);
    return;
  }

  lastCode=data.code;
  lastMessage=[
    "━━━━━━━━━━━━━━━━━━━━",
    "PRELUDE",
    "Descubrimiento confirmado",
    "━━━━━━━━━━━━━━━━━━━━",
    "",
    `Pedido: #${data.order_number}`,
    `Cliente: ${data.customer_name}`,
    `Total confirmado: ${Number(data.order_total).toFixed(2).replace(".",",")} €`,
    `Marcapáginas añadidos: ${data.bookmarks_awarded}`,
    "",
    "Código de Colección Prelude",
    "",
    data.code,
    "",
    "Este código desbloqueará:",
    "",
    ...data.perfumes.map(name=>`• ${name}`),
    "",
    "Introdúcelo en Mi Colección Prelude para incorporar tus nuevas obras.",
    "",
    "Every Masterpiece Begins With A Prelude.",
    "━━━━━━━━━━━━━━━━━━━━"
  ].join("\n");

  document.getElementById("generatedCode").textContent=lastCode;
  document.getElementById("whatsappMessage").textContent=lastMessage;
  document.getElementById("result").classList.add("open");
  status(generateStatus,"Código creado correctamente.");
  await loadHistory();
}

async function loadHistory(){
  const { data,error }=await client.rpc("admin_list_prelude_codes");
  const history=document.getElementById("history");

  if(error){
    history.innerHTML='<p class="error">No se pudo cargar el historial.</p>';
    return;
  }

  if(!data||data.length===0){
    history.innerHTML='<p style="color:var(--muted)">Todavía no hay códigos.</p>';
    return;
  }

  history.innerHTML=data.map(item=>`
    <div class="history-item">
      <div class="row"><strong>${item.code}</strong><span>${item.is_redeemed?"Canjeado":"Pendiente"}</span></div>
      <div>${item.customer_name||"Sin nombre"} · Pedido #${item.order_number||"—"}</div>
      <div style="color:var(--muted);margin-top:4px">${item.perfumes.join(", ")}</div>
    </div>
  `).join("");
}

async function copyText(value,button){
  await navigator.clipboard.writeText(value);
  const original=button.textContent;
  button.textContent="Copiado";
  setTimeout(()=>button.textContent=original,1200);
}


codesTabBtn.addEventListener("click",()=>switchStudioView("codes"));
customersTabBtn.addEventListener("click",()=>switchStudioView("customers"));
rankingTabBtn.addEventListener("click",()=>switchStudioView("ranking"));
refreshRankingBtn.addEventListener("click",loadAdminRanking);
customerSearch.addEventListener("input",()=>{
  const query=customerSearch.value.trim().toLowerCase();
  renderCustomers(customersCache.filter(item=>
    item.customer_name.toLowerCase().includes(query)||
    item.customer_phone.includes(query)
  ));
});
closeCustomerDetail.addEventListener("click",()=>customerDetail.classList.remove("open"));
saveCustomerBtn.addEventListener("click",saveCustomer);
resetCustomerBtn.addEventListener("click",()=>openDangerConfirm("reset"));
deleteCustomerBtn.addEventListener("click",()=>openDangerConfirm("delete"));
cancelConfirmBtn.addEventListener("click",closeDangerConfirm);
confirmActionBtn.addEventListener("click",executeDangerAction);
confirmOverlay.addEventListener("click",event=>{
  if(event.target===confirmOverlay)closeDangerConfirm();
});

document.getElementById("loginBtn").addEventListener("click",login);
document.getElementById("password").addEventListener("keydown",event=>{if(event.key==="Enter")login();});
document.getElementById("logoutBtn").addEventListener("click",logout);
document.getElementById("generateBtn").addEventListener("click",generateCode);
document.getElementById("copyCodeBtn").addEventListener("click",event=>copyText(lastCode,event.currentTarget));
document.getElementById("copyMessageBtn").addEventListener("click",event=>copyText(lastMessage,event.currentTarget));

if(client){
  client.auth.getSession().then(({data})=>{
    if(data.session)showDashboard();
  }).catch(error=>console.error(error));
}else{
  status(loginStatus,"No se ha podido cargar Supabase. Recarga la página.",true);
}
