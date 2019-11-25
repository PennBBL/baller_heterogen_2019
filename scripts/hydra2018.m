function model=hydra2018(XK,Y,Cov,params);
%% Parameters:
% numconsensus -- (int>=0) 0 for no consensus, positive integer for number of consensus
% runs
% numiter -- (int>0) number of iterative assignment steps
% C -- (real>0) loss penalty
% k -- (int>0) number of polytope faces (final number may be less due to
% face dropping)
% kernel -- (0 (default) or 1), treat XK as X*X' solve dual problem (1), else XK is X
% solve primal(0)
% init_type -- 0 : assignment by random hyperplanes (not supported for regression), 1 : pure random
% assignment, 2: k-means assignment (default), 3: assignment by DPP random
% hyperplanes
% reg_type -- (1 or 2): 1 solves L1-SVM, 2 solves L2-SVM
%% parameters
if ~isfield(params,'numconsensus')
    params.numconsensus=50;
end
if ~isfield(params,'numiter')
    params.numiter=20;
end
if ~isfield(params,'C')
    params.C=1;
end
if ~isfield(params,'k')
    params.k=1;
end
if ~isfield(params,'kernel')
    params.kernel=0;
end
if ~isfield(params,'init_type')
    params.init_type=2;
end
if ~isfield(params,'balanceclasses')
    params.balanceclasses=1;
    
end
if ~isfield(params,'fixedclustering')
    params.fixedclustering=0;
end
if ~isfield(params,'fixedclusteringIDX')
    params.fixedclusteringIDX=ones(size(XK,1),1);
end
if ~isfield(params,'reg_type');
    params.reg_type=2;
end

params.type='classification';
initparams.init_type=params.init_type;
%% algorithms


switch params.type
    case 'classification'
        initparams.regression=0;
        if params.fixedclustering==1
            params.k=numel(unique(params.fixedclusteringIDX(Y==1,1)));
            [~,~,params.fixedclusteringIDX(Y==1,1)]=unique(params.fixedclusteringIDX(Y==1,1));
        end
        
        if params.reg_type==2;
                if params.kernel==0
                    svmX=XK;
                    svmparams='-t 0';
                    initparams.kernel=0;
                elseif params.kernel==1
                    svmX=[(1:size(XK,1))' XK];
                    svmparams='-t 4';
                    initparams.kernel=1;
                end
                
                if params.fixedclustering==0
                    IDX=zeros(size(Y(Y==1,:),1),params.numconsensus);
                    for tt=1:params.numconsensus
                        W=ones(size(Y,1),params.k)/params.k;
                        W(Y==1,:)=hydra_init_v2(XK,Y,params.k,initparams);
                        S=zeros(size(W));
                        cn=zeros(1,params.k);cp=zeros(1,params.k);nrm=zeros(1,params.k);
                        for t=1:params.numiter
                            for j=1:params.k
                                cn(1,j)=1./mean(W(Y==-1,j),1);
                                cp(1,j)=1./mean(W(Y==1,j),1);
                                nrm(1,j)=cn(1,j)+cp(1,j);
                                cn(1,j)=cn(1,j)/nrm(1,j);
                                cp(1,j)=cp(1,j)/nrm(1,j);
                                if params.balanceclasses==1
                                   % mdl{j}=w_svmtrain(XK,Y,W(:,j),params.C,cp(1,j),cn(1,j),params.kernel);
                                    mdl{j}=svmtrain(W(:,j),Y,svmX,['-s 0 -c ' num2str(params.C) ' -q -w-1 ' num2str(cn(1,j)) ' -w1 ' num2str(cp(1,j)) ' ' svmparams]);
                                else
%                                     mdl{j}=w_svmtrain(XK,Y,W(:,j),params.C,1,1,params.kernel);
                                  mdl{j}= svmtrain(W(:,j),Y,svmX,['-s 0 -c ' num2str(params.C) ' -q ' svmparams]);
                                end
                                [~,~,S(:,j)]=svmpredict(Y,svmX,mdl{j},'-q');
%                                 S(:,j)=w_svmpredict(XK,mdl{j},params.kernel);
                            end
                            [~,idx]=max(S(Y==1,:),[],2);
                            Wold=W;
                            W(Y==1,:)=0;
                            W(sub2ind(size(W),find(Y==1),idx))=1;
                            if norm(W-Wold,'fro')<1e-6;
                                disp('converged');
                                break
                            end
                        end
                        IDX(:,tt)=idx;
                        
                    end
                    
                    if params.numconsensus>1
                        IDXfinal=consensus_clustering(IDX,params.k);
                        W=zeros(size(Y,1),params.k);
                        W(sub2ind(size(W),find(Y==1),IDXfinal))=1;
                        W(Y==-1,:)=1/params.k;
                        cn=zeros(1,params.k);cp=zeros(1,params.k);nrm=zeros(1,params.k);
                        for j=1:params.k
                            cn(1,j)=1./mean(W(Y==-1,j),1);
                            cp(1,j)=1./mean(W(Y==1,j),1);
                            nrm(1,j)=cn(1,j)+cp(1,j);
                            cn(1,j)=cn(1,j)/nrm(1,j);
                            cp(1,j)=cp(1,j)/nrm(1,j);
                            if params.balanceclasses==1
%                                 mdl{j}=w_svmtrain(XK,Y,W(:,j),params.C,cp(1,j),cn(1,j),params.kernel);
                               mdl{j}= svmtrain(W(:,j),Y,svmX,['-s 0 -c ' num2str(params.C) ' -q -w-1 ' num2str(cn(1,j)) ' -w1 ' num2str(cp(1,j)) ' ' svmparams]);
                            else
%                                 mdl{j}=w_svmtrain(XK,Y,W(:,j),params.C,1,1,params.kernel);
                              mdl{j}=  svmtrain(W(:,j),Y,svmX,['-s 0 -c ' num2str(params.C) ' -q ' svmparams]);
                            end
                        end
                        
                    else
                        IDXfinal=IDX;
                    end
                    
                elseif params.fixedclustering==1
                    IDXfinal=params.fixedclusteringIDX(Y==1,1);
                    W=zeros(size(Y,1),params.k);
                    W(sub2ind(size(W),find(Y==1),IDXfinal))=1;
                    W(Y==-1,:)=1/params.k;
                    cn=zeros(1,params.k);cp=zeros(1,params.k);nrm=zeros(1,params.k);
                    for j=1:params.k
                        cn(1,j)=1./mean(W(Y==-1,j),1);
                        cp(1,j)=1./mean(W(Y==1,j),1);
                        nrm(1,j)=cn(1,j)+cp(1,j);
                        cn(1,j)=cn(1,j)/nrm(1,j);
                        cp(1,j)=cp(1,j)/nrm(1,j);
                        if params.balanceclasses==1
%                             mdl{j}=w_svmtrain(XK,Y,W(:,j),params.C,cp(1,j),cn(1,j),params.kernel);
                            mdl{j}=svmtrain(W(:,j),Y,svmX,['-s 0 -c ' num2str(params.C) ' -q -w-1 ' num2str(cn(1,j)) ' -w1 ' num2str(cp(1,j)) ' ' svmparams]);
                        else
%                             mdl{j}=w_svmtrain(XK,Y,W(:,j),params.C,1,1,params.kernel);
                            mdl{j}=svmtrain(W(:,j),Y,svmX,['-s 0 -c ' num2str(params.C) ' -q ' svmparams]);
                        end
                    end
                    
                end
                model.mdl=mdl;
                model.S=W(Y==1,:);
                model.W=W;
                model.Yhat=Y;
                model.Yhat(Y==1)=IDXfinal;
                model.cn=cn;
                model.cp=cp;
        end
        if params.reg_type==1
                if params.kernel==0
                    svmX=sparse(XK);
                    initparams.kernel=0;
                    svmparams='-B 1';
                elseif params.kernel==1
                    error('Kernel in sparse SVM not supported');
                end
                if params.fixedclustering==0
                    IDX=zeros(size(Y(Y==1,:),1),params.numconsensus);
                    for tt=1:params.numconsensus
                        W=ones(size(Y,1),params.k)/params.k;
                        W(Y==1,:)=hydra_init_v2(XK,Y,params.k,initparams);
                        S=zeros(size(W));
                        cn=zeros(1,params.k);cp=zeros(1,params.k);nrm=zeros(1,params.k);
                        for t=1:params.numiter
                            for j=1:params.k
                                cn(1,j)=1./mean(W(Y==-1,j),1);
                                cp(1,j)=1./mean(W(Y==1,j),1);
                                nrm(1,j)=cn(1,j)+cp(1,j);
                                cn(1,j)=cn(1,j)/nrm(1,j);
                                cp(1,j)=cp(1,j)/nrm(1,j);
                                if params.balanceclasses==1
                                   % mdl{j}=w_train(XK,Y,W(:,j),params.C,cp(1,j),cn(1,j));
                                     mdl{j}=train(W(:,j),sparse(Y),svmX,['-s 5 -c ' num2str(params.C) ' -q -w-1 ' num2str(cn(1,j)) ' -w1 ' num2str(cp(1,j)) ' ' svmparams]);
                                else
                                    %mdl{j}=w_train(XK,Y,W(:,j),params.C,1,1);
                                     mdl{j}= train(W(:,j),sparse(Y),svmX,['-s 5 -c ' num2str(params.C) ' -q ' svmparams]);
                                end
                                [~,~,S(:,j)]=predict(Y,svmX,mdl{j},'-q');
%                                 S(:,j)=w_svmpredict(XK,mdl{j},0);
                            end
                            [~,idx]=max(S(Y==1,:),[],2);
                            Wold=W;
                            W(Y==1,:)=0;
                            W(sub2ind(size(W),find(Y==1),idx))=1;
                            if norm(W-Wold,'fro')<1e-6;
                                disp('converged');
                                break
                            end
                        end
                        IDX(:,tt)=idx;
                        
                    end
                    
                    if params.numconsensus>1
                        IDXfinal=consensus_clustering(IDX,params.k);
                        W=zeros(size(Y,1),params.k);
                        W(sub2ind(size(W),find(Y==1),IDXfinal))=1;
                        W(Y==-1,:)=1/params.k;
                        cn=zeros(1,params.k);cp=zeros(1,params.k);nrm=zeros(1,params.k);
                        for j=1:params.k
                            cn(1,j)=1./mean(W(Y==-1,j),1);
                            cp(1,j)=1./mean(W(Y==1,j),1);
                            nrm(1,j)=cn(1,j)+cp(1,j);
                            cn(1,j)=cn(1,j)/nrm(1,j);
                            cp(1,j)=cp(1,j)/nrm(1,j);
                            if params.balanceclasses==1
                               % mdl{j}=w_train(XK,Y,W(:,j),params.C,cp(1,j),cn(1,j));
                                mdl{j}= train(W(:,j),sparse(Y),svmX,['-s 5 -c ' num2str(params.C) ' -q -w-1 ' num2str(cn(1,j)) ' -w1 ' num2str(cp(1,j)) ' ' svmparams]);
                            else
                               % mdl{j}=w_train(XK,Y,W(:,j),params.C,1,1);
                                mdl{j}= train(W(:,j),sparse(Y),svmX,['-s 5 -c ' num2str(params.C) ' -q ' svmparams]);%%gc: from liblinear
                            end
                        end
                        
                    else
                        IDXfinal=IDX;
                    end
                elseif params.fixedclustering==1
                    IDXfinal=params.fixedclusteringIDX(Y==1,1);
                    W=zeros(size(Y,1),params.k);
                    W(sub2ind(size(W),find(Y==1),IDXfinal))=1;
                    W(Y==-1,:)=1/params.k;
                    cn=zeros(1,params.k);cp=zeros(1,params.k);nrm=zeros(1,params.k);
                    for j=1:params.k
                        cn(1,j)=1./mean(W(Y==-1,j),1);
                        cp(1,j)=1./mean(W(Y==1,j),1);
                        nrm(1,j)=cn(1,j)+cp(1,j);
                        cn(1,j)=cn(1,j)/nrm(1,j);
                        cp(1,j)=cp(1,j)/nrm(1,j);
                        if params.balanceclasses==1
%                             mdl{j}=w_train(XK,Y,W(:,j),params.C,cp(1,j),cn(1,j));
                           mdl{j}= train(W(:,j),sparse(Y),svmX,['-s 5 -c ' num2str(params.C) ' -q -w-1 ' num2str(cn(1,j)) ' -w1 ' num2str(cp(1,j)) ' ' svmparams]);
                        else
                            %mdl{j}=w_train(XK,Y,W(:,j),params.C,1,1);
                            mdl{j}=train(W(:,j),sparse(Y),svmX,['-s 5 -c ' num2str(params.C) ' -q ' svmparams]);
                        end
                    end
                    
                end
                model.mdl=mdl;
                model.S=W(Y==1,:);
                model.W=W;
                model.Yhat=Y;
                model.Yhat(Y==1)=IDXfinal;
                model.cn=cn;
                model.cp=cp;
        end
    
end

model.params=params;
end

function IDXfinal=consensus_clustering(IDX,k)
[n,~]=size(IDX);
cooc=zeros(n);
for i=1:n-1
    for j=i+1:n
        cooc(i,j)=sum(IDX(i,:)==IDX(j,:));
    end
    %cooc(i,i)=sum(IDX(i,:)==IDX(i,:))/2;
end
cooc=cooc+cooc';
L=diag(sum(cooc,2))-cooc;

Ln=eye(n)-diag(sum(cooc,2).^(-1/2))*cooc*diag(sum(cooc,2).^(-1/2));
Ln(isnan(Ln))=0;
[V,~]=eig(Ln);
try
    IDXfinal=kmeans(V(:,1:k),k,'emptyaction','drop','replicates',20);
catch
    disp('Complex Eigenvectors Found...Using Non-Normalized Laplacian');
    [V,~]=eig(L);
    IDXfinal=kmeans(V(:,1:k),k,'emptyaction','drop','replicates',20);
end

end

function [S,Yhat]=hydra_init_v2(XK,Y,k,params)
nker=@(K)(K./sqrt(diag(K)*diag(K)'));
init_type=params.init_type;
if params.regression==0
    if params.kernel==0
        X=XK;
        if init_type==0; %% Random hyperplanes
            idxp=find(Y==1);
            idxn=find(Y==-1);
            prob=zeros(size(X(Y==1,:),1),k);
            for j=1:k
                ip=randi(length(idxp));
                in=randi(length(idxn));
                w0=(X(idxp(ip),:)-X(idxn(in),:));
                w0=w0/norm(w0);
                prob(:,j)=bsxfun(@times,X(Y==1,:),1./norms(X(Y==1,:),2,2))*w0';
            end
            l=min(prob-1,0);
            d=prob-1;
            S=LP1(l,d);
        elseif init_type==1; %% Random assignment
            S=drchrnd(ones(1,k),size(X(Y==1,:),1));
        elseif init_type==2; %% K-means
            IDX=kmeans(X(Y==1,:),k,'replicates',20);
            S=zeros(size(X(Y==1,:),1),k);
            S(sub2ind(size(S),(1:size(S,1))',IDX))=1;
        elseif init_type==3; %% DPP random hyperplanes
            idxp=find(Y==1);
            idxn=find(Y==-1);
            num=size(X,1);
            W=zeros(num,size(X,2));
            for j=1:num
                ip=randi(length(idxp));
                in=randi(length(idxn));
                W(j,:)=(X(idxp(ip),:)-X(idxn(in),:));
            end
            KW=W*W';
            KW=KW./sqrt(diag(KW)*diag(KW)');
            Widx = sample_dpp(decompose_kernel(KW),k);
            prob=zeros(size(X(Y==1,:),1),k);
            for j=1:k
                prob(:,j)=bsxfun(@times,X(Y==1,:),1./norms(X(Y==1,:),2,2))*(W(Widx(j),:))';
            end
            l=min(prob-1,0);
            d=prob-1;
            S=LP1(l,d);
        end
        Yhat=-ones(size(Y));
        [~,Yhat(Y==1)]=max(S,[],2);
    elseif params.kernel==1
        K=XK;
        if init_type==0
            Kn=nker(K);
            idxp=find(Y==1);
            idxn=find(Y==-1);
            prob=zeros(size(K(Y==1,:),1),k);
            for j=1:k
                ip=randi(length(idxp));
                in=randi(length(idxn));
                prob(:,j)=Kn(:,idxp(ip))-Kn(:,idxn(in));
            end
            l=min(prob-1,0);
            d=prob-1;
            S=LP1(l,d);
        elseif init_type==1
            S=drchrnd(ones(1,k),size(K(Y==1,:),1));
        elseif init_type==2
            IDX=knkmeans(K(Y==1,Y==1),k,20);
            S=zeros(size(K(Y==1,:),1),k);
            S(sub2ind(size(S),(1:size(S,1))',IDX))=1;
        elseif init_type==3;
            Kn=nker(K);
            idxp=find(Y==1);
            idxn=find(Y==-1);
            num=size(K,1);
            KW=zeros(num,num);
            KWidxp=zeros(num,1);
            KWidxn=zeros(num,1);
            for i=1:num
                KWidxp(i,1)=randi(length(idxp));
                KWidxn(i,1)=randi(length(idxn));
            end
            for i=1:num
                for j=i:num
                    KW(i,j)=K(idxp(KWidxp(i,1)),idxp(KWidxp(j,1)))+K(idxn(KWidxn(i,1)),idxn(KWidxn(j,1)))-K(idxp(KWidxp(i,1)),idxn(KWidxn(j,1)))-K(idxn(KWidxn(i,1)),idxp(KWidxp(j,1)));
                    KW(j,i)=KW(i,j);
                end
            end
            KW=KW./sqrt(diag(KW)*diag(KW)');
            Widx = sample_dpp(decompose_kernel(KW),k);
            prob=zeros(size(K(Y==1,:),1),k);
            for j=1:k
                prob(:,j)=Kn(Y==1,idxp(KWidxp(Widx(j))))-Kn(Y==1,idxn(KWidxn(Widx(j))));
            end
            l=min(prob-1,0);
            d=prob-1;
            S=LP1(l,d);
        end
        Yhat=-ones(size(Y));
        [~,Yhat(Y==1)]=max(S,[],2);
    end
end
end

function s=LP1(l,d)
% Proportional assignment based on margin
invL=1./l;
idx=find(invL==Inf);
invL(idx)=d(idx);
for i=1:size(invL,1)
    pos=find(invL(i,:)>0); %#ok<*EFIND>
    neg=find(invL(i,:)<0);
    if ~isempty(pos)
        invL(i,neg)=0; %#ok<*FNDSB>
    else
        invL(i,:)=invL(i,:)/min(invL(i,:),[],2);
        invL(i,invL(i,:)<1)=0;
    end
end
s=bsxfun(@times,invL,1./sum(invL,2));
end

function epsilon=svr_parameter_selection(XK,Y,params)
sigma=noise_estimator(XK,Y,params);
epsilon=3*sigma*sqrt(log(size(XK,1))/size(XK,1));
end

function sigma=noise_estimator(XK,Y,params)

if params.kernel==1
    Ypred=loo_kernel_knn(XK,Y,5);
elseif params.kernel==0
    K=XK*XK';
    Ypred=loo_kernel_knn(K,Y,5);
end

sigma=sqrt((5/4)*(1/size(XK,1))*sum((Y-Ypred).^2));
end

function Ypred=loo_kernel_knn(K,Y,k)
[n,~]=size(K);
D=kernel2dist(K);
Ypred=zeros(n,1);
for i=1:n
    Yi=Y((1:n)~=i);
    [~,idx]=sort(D(i,(1:n)~=i),2,'ascend');
    Ypred(i,1)=mean(Yi(idx(1:k)));
end
end

function D=kernel2dist(K)
D=zeros(size(K));
for i=1:size(K,1)-1
    for j=i+1:size(K,1)
        D(i,j)=K(i,i)+K(j,j)-2*K(i,j);
    end
end
D=D+D';
end

function Y = sample_dpp(L,k)
% sample a set Y from a dpp.  L is a decomposed kernel, and k is (optionally)
% the size of the set to return.

if ~exist('k','var')
    % choose eigenvectors randomly
    D = L.D ./ (1+L.D);
    v = find(rand(length(D),1) <= D);
else
    % k-DPP
    v = sample_k(L.D,k);
end
k = length(v);
V = L.V(:,v);

% iterate
Y = zeros(k,1);
for i = k:-1:1
    
    % compute probabilities for each item
    P = sum(V.^2,2);
    P = P / sum(P);
    
    % choose a new item to include
    Y(i) = find(rand <= cumsum(P),1);
    
    % choose a vector to eliminate
    j = find(V(Y(i),:),1);
    Vj = V(:,j);
    V = V(:,[1:j-1 j+1:end]);
    
    % update V
    V = V - bsxfun(@times,Vj,V(Y(i),:)/Vj(Y(i)));
    
    % orthogonalize
    for a = 1:i-1
        for b = 1:a-1
            V(:,a) = V(:,a) - V(:,a)'*V(:,b)*V(:,b);
        end
        V(:,a) = V(:,a) / norm(V(:,a));
    end
    
end

Y = sort(Y);
end

function L = decompose_kernel(M)
L.M = M;
[V,D] = eig(M);
L.V = real(V);
L.D = real(diag(D));
end

function S = sample_k(lambda,k)
% pick k lambdas according to p(S) \propto prod(lambda \in S)

% compute elementary symmetric polynomials
E = elem_sympoly(lambda,k);

% iterate
i = length(lambda);
remaining = k;
S = zeros(k,1);
while remaining > 0
    
    % compute marginal of i given that we choose remaining values from 1:i
    if i == remaining
        marg = 1;
    else
        marg = lambda(i) * E(remaining,i) / E(remaining+1,i+1);
    end
    
    % sample marginal
    if rand < marg
        S(remaining) = i;
        remaining = remaining - 1;
    end
    i = i-1;
end
end

function E = elem_sympoly(lambda,k)
% given a vector of lambdas and a maximum size k, determine the value of
% the elementary symmetric polynomials:
%   E(l+1,n+1) = sum_{J \subseteq 1..n,|J| = l} prod_{i \in J} lambda(i)

N = length(lambda);
E = zeros(k+1,N+1);
E(1,:) = 1;
for l = (1:k)+1
    for n = (1:N)+1
        E(l,n) = E(l,n-1) + lambda(n-1)*E(l-1,n-1);
    end
end
end

function [label, energy,LABEL,ENERGY] = knkmeans(K,init,replicates)
% Perform kernel k-means clustering.
%   K: kernel matrix
%   init: k (1 x 1) or label (1 x n, 1<=label(i)<=k)
% Reference: [1] Kernel Methods for Pattern Analysis
% by John Shawe-Taylor, Nello Cristianini
% Written by Michael Chen (sth4nth@gmail.com).
if nargin<3
    replicates=20;
end
LABEL=zeros(size(K,1),replicates);
ENERGY=zeros(1,replicates);
for TT=1:replicates
    n = size(K,1);
    if length(init) == 1
        label = ceil(init*rand(1,n));
    elseif size(init,1) == 1 && size(init,2) == n
        label = init;
    else
        error('ERROR: init is not valid.');
    end
    last = 0;
    while any(label ~= last)
        [u,~,label] = unique(label,'legacy');   % remove empty clusters
        k = length(u);
        E = sparse(label,1:n,1,k,n,n);
        E = bsxfun(@times,E,1./sum(E,2));
        T = E*K;
        Z = repmat(diag(T*E'),1,n)-2*T;
        last = label;
        [val, label] = min(Z,[],1);
    end
    [~,~,label] = unique(label,'legacy');   % remove empty clusters
    LABEL(:,TT)=label';
    ENERGY(:,TT) = sum(val)+trace(K);
end
[energy,IDX]=min(ENERGY,[],2);
label=LABEL(:,IDX);
end

function r = drchrnd(a,n)
% take a sample from a dirichlet distribution
p = length(a);
r = gamrnd(repmat(a,n,1),1,n,p);
r = r ./ repmat(sum(r,2),1,p);
end

function cvx_optval = norms( x, p, dim )
%NORMS Computation of multiple vector norms.
% NORMS( X ) provides a means to compute the norms of multiple vectors
% packed into a matrix or N-D array. This is useful for performing
% max-of-norms or sum-of-norms calculations.
%
% All of the vector norms, including the false "-inf" norm, supported
% by NORM() have been implemented in the NORMS() command.
% NORMS(X,P) = sum(abs(X).^P).^(1/P)
% NORMS(X) = NORMS(X,2).
% NORMS(X,inf) = max(abs(X)).
% NORMS(X,-inf) = min(abs(X)).
% If X is a vector, these computations are completely identical to
% their NORM equivalents. If X is a matrix, a row vector is returned
% of the norms of each column of X. If X is an N-D matrix, the norms
% are computed along the first non-singleton dimension.
%
% NORMS( X, [], DIM ) or NORMS( X, 2, DIM ) computes Euclidean norms
% along the dimension DIM. NORMS( X, P, DIM ) computes its norms
% along the dimension DIM.
%
% Disciplined convex programming information:
% NORMS is convex, except when P<1, so an error will result if these
% non-convex "norms" are used within CVX expressions. NORMS is
% nonmonotonic, so its input must be affine.
%
% Check second argument
%
error( nargchk( 1, 3, nargin ) ); %#ok
if nargin < 2 || isempty( p ),
    p = 2;
elseif ~isnumeric( p ) || numel( p ) ~= 1 || ~isreal( p ),
    error( 'Second argument must be a real number.' );
elseif p < 1 || isnan( p ),
    error( 'Second argument must be between 1 and +Inf, inclusive.' );
end
%
% Check third argument
%
% sx = size( x );
% if nargin < 3 || isempty( dim ),
% dim = cvx_default_dimension( sx );
% elseif ~cvx_check_dimension( dim, false ),
% error( 'Third argument must be a valid dimension.' );
% elseif isempty( x ) || dim > length( sx ) || sx( dim ) == 1,
% p = 1;
% end
%
% Compute the norms
%
switch p,
    case 1,
        cvx_optval = sum( abs( x ), dim );
    case 2,
        cvx_optval = sqrt( sum( x .* conj( x ), dim ) );
    case Inf,
        cvx_optval = max( abs( x ), [], dim );
    otherwise,
        cvx_optval = sum( abs( x ) .^ p, dim ) .^ ( 1 / p );
end
% Copyright 2005-2014 CVX Research, Inc.
% See the file LICENSE.txt for full copyright information.
% The command 'cvx_where' will show where this file is located.
end

function mdl=w_svmtrain(X,Y,W,C,Cp,Cn,dual)
if any(isnan([Cp Cn]))
    mdl.w=zeros(size(X,2),1);
    mdl.b=0;
    warning('Cluster dropped');
    return
end
if dual==0
    X=X;
elseif dual==1
    [U,S,~]=svd(X);
    X=U*sqrt(S);
    
end
idxp=find(Y==1);
idxn=find(Y==-1);
Cw=zeros(size(Y));
Cw(idxp)=Cp;
Cw(idxn)=Cn;
[n,d] = size(X);
H = diag([ones(1, d), zeros(1, n + 1)]);
f = [zeros(1,d+1) C*(ones(1,n).*W'.*Cw')]';
p = diag(Y) * X;
A = -[p Y eye(n)];
B = -ones(n,1);
lb = [-inf * ones(d+1,1) ;zeros(n,1)];
options=optimoptions('quadprog','Display','off');
z = quadprog(H,f,A,B,[],[],lb,[],[],options);

mdl.w = z(1:d,:);
mdl.b = z(d+1:d+1,:);
mdl.eps = z(d+2:d+n+1,:);
end

function mdl=w_train(X,Y,W,C,Cp,Cn)
if any(isnan([Cp Cn]))
    mdl.w=zeros(size(X,2),1);
    mdl.b=0;
    warning('Cluster dropped');
    return
end
idxp=find(Y==1);
idxn=find(Y==-1);
Cw=zeros(size(Y,1),1);
Cw(idxp)=Cp;
Cw(idxn)=Cn;
[n,d]=size(X);
f=[ones(d,1);ones(d,1);zeros(1,1);C*W.*Cw.*ones(n,1)];
A=-[diag(Y)*X -diag(Y)*X Y eye(n)];
b=-ones(n,1);
lb=[zeros(d,1);zeros(d,1);-inf(1,1);zeros(n,1)];
ub=[inf(d,1);inf(d,1);inf(1,1);inf(n,1)];
options=optimoptions('linprog','Display','off');
v = linprog(f,A,b,[],[],lb,ub,[],options);

mdl.w=v(1:d)-v(d+1:2*d);
mdl.b=v(2*d+1);
end

function S=w_svmpredict(X,mdl,dual)

if dual==0
    X=X;
elseif dual==1
    [U,S,~]=svd(X);
    X=U*sqrt(S);
    
end

S=X*mdl.w+mdl.b;

end