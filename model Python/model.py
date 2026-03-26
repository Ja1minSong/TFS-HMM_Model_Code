# model.py

import torch
from torch import nn
from torch.nn import functional as F
from torch.nn.modules.utils import _triple

class SpatioTemporalConv(nn.Module):
    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0, bias=False):
        super(SpatioTemporalConv, self).__init__()
        kernel_size = _triple(kernel_size)
        stride = _triple(stride)
        padding = _triple(padding)
        self.temporal_spatial_conv = nn.Conv3d(in_channels, out_channels, kernel_size, stride=stride, padding=padding, bias=bias)
        self.bn = nn.BatchNorm3d(out_channels)
        self.relu = nn.ReLU()

    def forward(self, x):
        x = self.bn(self.temporal_spatial_conv(x))
        x = self.relu(x)
        return x

class SELayer(nn.Module):
    def __init__(self, out_channels, reduction=16):
        super(SELayer, self).__init__()
        self.reduction = reduction
        self.fc = nn.Sequential(
            nn.Linear(out_channels, out_channels // reduction, bias=False),
            nn.ReLU(inplace=True),
            nn.Linear(out_channels // reduction, out_channels, bias=False),
            nn.Sigmoid()
        )

    def forward(self, x):
        b, c = x.size(0), x.size(1)
        if x.dim() == 5:
            y = F.adaptive_avg_pool3d(x, 1).view(b, c)
        elif x.dim() == 4:
            y = F.adaptive_avg_pool2d(x, 1).view(b, c)
        else:
            raise ValueError("SELayer expects 4D or 5D input")
        y = self.fc(y).view(b, c, *([1] * (x.dim() - 2)))
        return y

class SpatioTemporalResBlock(nn.Module):
    def __init__(self, in_channels, out_channels, kernel_size, output_channels, downsample=False):
        super(SpatioTemporalResBlock, self).__init__()
        padding = kernel_size // 2
        self.downsample = downsample
        if self.downsample:
            self.downsampleconv = SpatioTemporalConv(in_channels, out_channels, 1, stride=2)
            self.downsamplebn = nn.BatchNorm3d(out_channels)
            self.conv1 = SpatioTemporalConv(in_channels, out_channels, kernel_size, padding=padding, stride=2)
        else:
            self.conv1 = SpatioTemporalConv(in_channels, out_channels, kernel_size, padding=padding)
        self.bn1 = nn.BatchNorm3d(out_channels)
        self.relu1 = nn.ReLU()
        self.conv2 = SpatioTemporalConv(out_channels, out_channels, kernel_size, padding=padding)
        self.bn2 = nn.BatchNorm3d(out_channels)
        self.outrelu = nn.ReLU()
        self.se = SELayer(out_channels)

    def forward(self, x, y):
        res = self.relu1(self.bn1(self.conv1(x)))
        res = self.bn2(self.conv2(res))
        res = res * self.se(res)
        if self.downsample:
            x = self.downsamplebn(self.downsampleconv(x))
        return self.outrelu(x + res)

class SpatioTemporalResLayer(nn.Module):
    def __init__(self, in_channels, out_channels, kernel_size, output_channels, layer_size, block_type=SpatioTemporalResBlock, downsample=False):
        super(SpatioTemporalResLayer, self).__init__()
        self.block1 = block_type(in_channels, out_channels, kernel_size, output_channels, downsample)
        self.blocks = nn.ModuleList([block_type(out_channels, out_channels, kernel_size, output_channels) for _ in range(layer_size - 1)])

    def forward(self, x, y):
        x = self.block1(x, y)
        for block in self.blocks:
            x = block(x, y)
        return x

class RNN(nn.Module):
    def __init__(self, input_size=18, hidden_size=64, num_layers=2):
        super(RNN, self).__init__()
        self.lstm = nn.LSTM(input_size, hidden_size, num_layers, batch_first=True)

    def forward(self, x):
        x = x.permute(0, 2, 1)
        h0 = torch.zeros(self.lstm.num_layers, x.size(0), self.lstm.hidden_size, device=x.device)
        c0 = torch.zeros(self.lstm.num_layers, x.size(0), self.lstm.hidden_size, device=x.device)
        out, _ = self.lstm(x, (h0, c0))
        return out[:, -1, :].view(x.size(0), 64, 1, 1)

def make_cnn_block():
    return nn.Sequential(
        nn.Conv2d(64, 64, 1, stride=1, padding=0, bias=False),
        nn.BatchNorm2d(64),
        nn.ReLU(inplace=True),
    )

class Net3Dto2D(nn.Module):
    def __init__(self):
        super(Net3Dto2D, self).__init__()
        self.conv1 = SpatioTemporalConv(18, 16, [3, 7, 7], stride=[1, 2, 2], padding=[1, 3, 3])
        self.maxpool = nn.MaxPool3d(kernel_size=[1, 2, 2], stride=[1, 2, 2], padding=[0, 1, 1])
        self.blk1_3D = SpatioTemporalResLayer(16, 16, 3, 64, 2)
        self.blk2_3D = SpatioTemporalResLayer(16, 32, 3, 64, 2, downsample=True)
        self.blk3_3D = SpatioTemporalResLayer(32, 64, 3, 64, 2, downsample=True)
        self.blk4_3D = SpatioTemporalResLayer(64, 128, 3, 64, 2, downsample=True)
        self.pool1 = nn.AdaptiveAvgPool3d(1)
        self.cnn = make_cnn_block()
        self.cnn1 = make_cnn_block()
        self.cnn2 = make_cnn_block()
        self.cnn3 = make_cnn_block()

    def forward(self, x, y):
        x = x.unsqueeze(2)
        x = self.conv1(x)
        x = self.maxpool(x)
        y = self.cnn(y)
        x = self.blk1_3D(x, y)
        y = self.cnn1(y)
        x = self.blk2_3D(x, y)
        y = self.cnn2(y)
        x = self.blk3_3D(x, y)
        y = self.cnn3(y)
        x = self.blk4_3D(x, y)
        x = self.pool1(x)
        return x.view(x.size(0), -1)

class InformationSharingGate(nn.Module):
    def __init__(self, cnn_dim, rnn_dim, common_dim, num_interactions=3):
        super(InformationSharingGate, self).__init__()
        self.common_dim = common_dim
        self.num_interactions = num_interactions
        self.cnn_proj = nn.Linear(cnn_dim, common_dim)
        self.rnn_proj = nn.Linear(rnn_dim, common_dim)
        self.cnn_gates = nn.ModuleList()
        self.rnn_gates = nn.ModuleList()
        self.cnn_linears = nn.ModuleList()
        self.rnn_linears = nn.ModuleList()
        for _ in range(num_interactions):
            self.cnn_gates.append(nn.Sequential(nn.ReLU(), nn.Softmax(dim=1)))
            self.rnn_gates.append(nn.Sequential(nn.ReLU(), nn.Softmax(dim=1)))
            self.cnn_linears.append(nn.Linear(common_dim, common_dim))
            self.rnn_linears.append(nn.Linear(common_dim, common_dim))
    def forward(self, cnn_feat, rnn_feat):
        cnn_feat_proj = self.cnn_proj(cnn_feat)
        rnn_feat_proj = self.rnn_proj(rnn_feat)
        for i in range(self.num_interactions):
            cnn_gated = self.cnn_gates[i](cnn_feat_proj) * cnn_feat_proj
            rnn_gated = self.rnn_gates[i](rnn_feat_proj) * rnn_feat_proj
            new_cnn_feat = self.cnn_linears[i](cnn_feat_proj + rnn_gated)
            new_rnn_feat = self.rnn_linears[i](rnn_feat_proj + cnn_gated)
            cnn_feat_proj = new_cnn_feat
            rnn_feat_proj = new_rnn_feat
        return cnn_feat_proj, rnn_feat_proj

class EEGNet(nn.Module):
    def __init__(self):
        super(EEGNet, self).__init__()
        self.rnn = RNN()
        self.backbone = Net3Dto2D()
        cnn_output_dim = 128
        rnn_output_dim = 64
        common_interaction_dim = 128
        self.info_gate = InformationSharingGate(
            cnn_dim=cnn_output_dim, 
            rnn_dim=rnn_output_dim, 
            common_dim=common_interaction_dim
        )
        self.fc1 = nn.Linear(common_interaction_dim * 2, 64)
        self.fc2 = nn.Linear(64, 2)
    def forward(self, raw, stft):
        rnn_feat = self.rnn(raw)
        cnn_feat = self.backbone(stft, rnn_feat)
        rnn_feat_flat = rnn_feat.view(rnn_feat.size(0), -1)
        cnn_feat_gated, rnn_feat_gated = self.info_gate(cnn_feat, rnn_feat_flat)
        x = torch.cat([cnn_feat_gated, rnn_feat_gated], dim=1)
        x = F.relu(self.fc1(x))
        x = self.fc2(x)
        return F.softmax(x, dim=1)